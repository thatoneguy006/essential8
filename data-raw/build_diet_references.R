# Maintainer-only build. Run from the package root, with internet access:
# Rscript data-raw/build_diet_references.R tmp/nhanes-cache
# Requires haven, survey, digest; 7z is used to read USDA self-extracting
# archives as data. The downloaded executables are NEVER executed.
# Raw files and participant scores stay in the ignored cache, not the package.

build_diet_references <- function(cache = "tmp/nhanes-cache", verify = FALSE) {
  for (package in c("haven", "survey", "digest")) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("Install the maintainer dependency: ", package)
    }
  }
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  cache <- normalizePath(cache, winslash = "/")
  options(timeout = max(600, getOption("timeout")))
  manifest <- list()
  fetch <- function(url, name = basename(url)) {
    path <- file.path(cache, name)
    if (!file.exists(path)) utils::download.file(url, path, mode = "wb")
    hash <- digest::digest(file = path, algo = "sha256")
    manifest[[name]] <<- data.frame(file = name, url = url, sha256 = hash)
    path
  }
  # Reuse the pre-existing, tested component calculator only in this build.
  env <- new.env(parent = globalenv())
  for (path in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
    sys.source(path, envir = env)
  }
  seven_zip <- Sys.which("7z")
  if (!nzchar(seven_zip) && file.exists("C:/Program Files/7-Zip/7z.exe")) {
    seven_zip <- "C:/Program Files/7-Zip/7z.exe"
  }
  if (!nzchar(seven_zip)) stop("Install 7-Zip and put 7z on PATH.")
  read_fped <- function(day, kind, short) {
    name <- sprintf("FPED_DR%d%s_%s_sas.exe", day, kind, short)
    archive <- fetch(paste0(
      "https://www.ars.usda.gov/ARSUserFiles/80400530/apps/", name
    ))
    folder <- file.path(cache, tools::file_path_sans_ext(name))
    file <- sprintf("fped_dr%d%s_%s.sas7bdat", day, tolower(kind), short)
    if (!file.exists(file.path(folder, file))) {
      dir.create(folder, showWarnings = FALSE)
      status <- system2(seven_zip, c("x", shQuote(archive),
                                    paste0("-o", shQuote(folder)), "-y"),
                        stdout = FALSE)
      if (status != 0L) stop("Cannot extract USDA archive: ", name)
    }
    as.data.frame(haven::read_sas(file.path(folder, file)))
  }
  read_nhanes <- function(stem, year, suffix) {
    file <- paste0(stem, "_", suffix, ".xpt")
    url <- paste0("https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/", year,
                  "/DataFiles/", file)
    as.data.frame(haven::read_xpt(fetch(url)))
  }

  # Published dietaryindex 2.1 food-code definitions, pinned to an immutable
  # revision. We use ONLY its numeric food-code lists, not its unweighted
  # quintiles or its practice of averaging separately scored recall days.
  # Source authors: James Jiada Zhan and Becky Hodge; source license: MIT.
  revision <- "b98cb9e4a5c514eeb4becf8fcd21d5da135b470c"
  code_path <- fetch(paste0("https://raw.githubusercontent.com/",
    "jamesjiadazhan/dietaryindex/", revision, "/R/DASH_NHANES_FPED.R"),
    "dietaryindex-dash.R")
  expected_hash <- "3ceb2d682a77a7e083f9055e949aead0c1636ff4b8902e4d423c68a978b383b8"
  stopifnot(identical(digest::digest(file = code_path, algo = "sha256"),
                      expected_hash))
  codes <- new.env(parent = baseenv())
  wanted <- c("COFFEE", "TEA", "COFFEE_TEA", "DRINK", "SSB",
              "SKIM_MILK", "LOWF_CHEESE")
  # Inspect static numeric assignments. Do not source downloaded code.
  collect_codes <- function(node) {
    if (missing(node)) return(invisible(NULL))
    if (!is.call(node)) return(invisible(NULL))
    if (as.character(node[[1]])[1] %in% c("=", "<-") &&
        is.symbol(node[[2]]) && as.character(node[[2]]) %in% wanted &&
        is.call(node[[3]]) && identical(node[[3]][[1]], as.name("c"))) {
      parts <- as.list(node[[3]])[-1]
      if (all(vapply(parts, function(x) is.numeric(x) ||
                     (is.symbol(x) && exists(as.character(x), codes,
                                             inherits = FALSE)), logical(1)))) {
        assign(as.character(node[[2]]), eval(node[[3]], codes), codes)
      }
    }
    for (child in as.list(node)[-1]) collect_codes(child)
    invisible(NULL)
  }
  for (expression in parse(code_path)) collect_codes(expression)
  stopifnot(all(vapply(wanted, exists, logical(1), envir = codes,
                      inherits = FALSE)))

  cycle_data <- function(year, suffix, short) {
    message("Reading NHANES ", year, " inputs")
    demo <- read_nhanes("DEMO", year, suffix)
    daily <- lapply(1:2, function(day) {
      nutrient <- read_nhanes(paste0("DR", day, "TOT"), year, suffix)
      food <- read_nhanes(paste0("DR", day, "IFF"), year, suffix)
      fped <- read_fped(day, "TOT", short)
      items <- read_fped(day, "IFF", short)
      prefix <- paste0("DR", day, "T_")
      item_prefix <- paste0("DR", day, "I_")
      id <- paste0("DR", day, "ILINE")
      food_code <- paste0("DR", day, "IFDCD")
      stopifnot(!anyDuplicated(paste(items$SEQN, items[[id]])),
                !anyDuplicated(paste(food$SEQN, food[[id]])),
                !anyDuplicated(nutrient$SEQN), !anyDuplicated(fped$SEQN))
      index <- match(paste(food$SEQN, food[[id]]),
                     paste(items$SEQN, items[[id]]))
      if (anyNA(index)) stop("Unmatched FPED food records in ", year)
      items <- items[index, ]
      stopifnot(all(items[[food_code]] == food[[food_code]]))
      item <- function(field) items[[paste0(item_prefix, field)]]
      milk <- ifelse(food[[food_code]] %in% codes$SKIM_MILK, item("D_MILK"), 0)
      cheese <- ifelse(food[[food_code]] %in% codes$LOWF_CHEESE,
                       item("D_CHEESE") * 4, 0)
      beverage <- ifelse(food[[food_code]] %in% codes$SSB,
                         item("ADD_SUGARS") * 4 / 26, 0)
      extras <- stats::aggregate(
        cbind(low_fat_dairy = milk + cheese + item("D_YOGURT"),
              sweetened_beverages = beverage),
        by = list(SEQN = food$SEQN), FUN = sum
      )
      fped <- fped[match(nutrient$SEQN, fped$SEQN), ]
      extras <- extras[match(nutrient$SEQN, extras$SEQN), ]
      fp <- function(field) fped[[paste0(prefix, field)]]
      nt <- function(field) nutrient[[paste0("DR", day, "T", field)]]
      output <- data.frame(
        SEQN = nutrient$SEQN,
        reliable = nutrient[[paste0("DR", day, "DRSTZ")]] == 1,
        energy = nt("KCAL"), sodium = nt("SODI"),
        poly = nt("PFAT"), mono = nt("MFAT"), sat = nt("SFAT"),
        fruits = fp("F_TOTAL"), whole_fruits = fp("F_CITMLB") + fp("F_OTHER"),
        vegetables = fp("V_TOTAL") + fp("V_LEGUMES"),
        greens_beans = fp("V_DRKGR") + fp("V_LEGUMES"),
        whole_grains = fp("G_WHOLE"), dairy = fp("D_TOTAL"),
        total_protein = fp("PF_MPS_TOTAL") + fp("PF_EGGS") +
          fp("PF_NUTSDS") + fp("PF_SOY") + fp("PF_LEGUMES"),
        plant_seafood = fp("PF_SEAFD_HI") + fp("PF_SEAFD_LOW") +
          fp("PF_NUTSDS") + fp("PF_SOY") + fp("PF_LEGUMES"),
        refined_grains = fp("G_REFINED"), added_sugars = fp("ADD_SUGARS"),
        dash_vegetables = fp("V_DRKGR") +
          (fp("V_REDOR_TOTAL") + fp("V_OTHER") + fp("V_STARCHY_OTHER")) / 0.5,
        nuts_legumes = fp("PF_LEGUMES") + fp("PF_NUTSDS") + fp("PF_SOY"),
        low_fat_dairy = extras$low_fat_dairy,
        red_meat = fp("PF_CUREDMEAT") / 1.5 +
          (fp("PF_MEAT") + fp("PF_ORGAN")) / 4,
        sweetened_beverages = extras$sweetened_beverages
      )
      if (day == 1) output$weight <- nutrient$WTDR2D
      output
    })
    first <- daily[[1]]
    second <- daily[[2]][match(first$SEQN, daily[[2]]$SEQN), ]
    stopifnot(all(is.na(second$SEQN) | first$SEQN == second$SEQN))
    good <- first$reliable & second$reliable &
      first$energy > 0 & second$energy > 0 & first$weight > 0
    values <- setdiff(names(first), c("SEQN", "reliable", "weight"))
    combined <- (first[values] + second[values]) / 2
    # Average nutrients/energy BEFORE applying ratios or diet scoring.
    combined$SEQN <- first$SEQN
    combined$weight <- first$weight / 2 # Two 2-year cycles form four years.
    combined$reliable <- good
    demo <- demo[match(first$SEQN, demo$SEQN), ]
    combined$age <- demo$RIDAGEYR
    combined$pregnant <- !is.na(demo$RIDEXPRG) & demo$RIDEXPRG == 1
    combined$stratum <- paste(suffix, demo$SDMVSTRA, sep = "_")
    combined$psu <- demo$SDMVPSU
    combined$cycle <- paste0(year, "-", as.integer(year) + 1L)
    combined
  }
  cohort <- rbind(cycle_data("2015", "I", "1516"),
                  cycle_data("2017", "J", "1718"))
  eligible <- !is.na(cohort$reliable) & cohort$reliable &
    stats::complete.cases(cohort)
  eligible_counts <- table(cohort$cycle[eligible])
  cohort <- cohort[eligible, ]
  design <- survey::svydesign(ids = ~psu, strata = ~stratum,
                              weights = ~weight, nest = TRUE, data = cohort)
  design <- subset(design, age >= 20 & !pregnant)
  cohort <- design$variables
  quantiles <- function(value, probabilities) {
    current <- design
    current$variables$index <- value
    as.numeric(stats::coef(survey::svyquantile(
      ~index, current, quantiles = probabilities, ci = FALSE, qrule = "math"
    )))
  }

  dash_inputs <- data.frame(
    dash_fruits = cohort$fruits, dash_vegetables = cohort$dash_vegetables,
    dash_nuts_and_legumes = cohort$nuts_legumes,
    dash_whole_grains = cohort$whole_grains,
    dash_low_fat_dairy = cohort$low_fat_dairy,
    dash_sodium = cohort$sodium / (cohort$energy / 2000),
    dash_red_and_processed_meat = cohort$red_meat,
    dash_sweetened_beverages = cohort$sweetened_beverages
  )
  component_cutpoints <- lapply(dash_inputs, quantiles,
                                probabilities = c(0.2, 0.4, 0.6, 0.8))
  names(component_cutpoints) <- sub("^dash_", "", names(component_cutpoints))
  # Retain the package's documented tie convention from PR #15.
  component_cutpoints$total <- c(8, 8, 8, 8) # Only raw total is used below.
  dash_total <- env$.compute_adult_dash(dash_inputs, NULL, component_cutpoints)$total
  hei_inputs <- data.frame(
    hei2015_energy_kcal = cohort$energy,
    hei2015_total_fruits = cohort$fruits, hei2015_whole_fruits = cohort$whole_fruits,
    hei2015_total_vegetables = cohort$vegetables,
    hei2015_greens_and_beans = cohort$greens_beans,
    hei2015_whole_grains = cohort$whole_grains, hei2015_dairy = cohort$dairy,
    hei2015_total_protein_foods = cohort$total_protein,
    hei2015_seafood_and_plant_proteins = cohort$plant_seafood,
    hei2015_polyunsaturated_fat = cohort$poly,
    hei2015_monounsaturated_fat = cohort$mono,
    hei2015_saturated_fat = cohort$sat,
    hei2015_refined_grains = cohort$refined_grains,
    hei2015_sodium = cohort$sodium, hei2015_added_sugars = cohort$added_sugars
  )
  hei_total <- env$.compute_adult_hei2015(hei_inputs, NULL, rep(100, 4))$total
  stopifnot(!anyNA(dash_total), !anyNA(hei_total))
  probability <- c(0.25, 0.5, 0.75, 0.95)
  make_reference <- function(total, method, definition, range) {
    cuts <- quantiles(total, probability)
    result <- env$diet_reference(cuts[1], cuts[2], cuts[3], cuts[4],
      method = method, score_range = range,
      label = "NHANES 2015-2018, nonpregnant adults aged 20+ with two reliable recalls",
      source = "Public CDC NHANES and USDA FPED; see data-raw/build_diet_references.R")
    result$provenance <- list(
      reference_name = "nhanes_2015_2018", reference_version = 1L,
      nhanes_cycles = c("2015-2016", "2017-2018"),
      index_definition = definition, n = nrow(cohort),
      n_by_cycle = as.list(table(cohort$cycle)),
      eligible_before_adult_domain = as.list(eligible_counts),
      weighting = "WTDR2D / 2; SDMVSTRA nested within cycle; SDMVPSU; nest=TRUE",
      recalls = "Mean of the same two reliable recalls before index calculation",
      exclusions = "Unreliable/missing recalls, nonpositive energy/weights, incomplete inputs, age<20, known pregnancy",
      percentile_method = "survey::svyquantile(qrule='math', ci=FALSE)",
      package_version_created = "0.3.0", dietaryindex_revision = revision,
      survey_version = as.character(utils::packageVersion("survey")),
      build_script_sha256 = digest::digest(file = "data-raw/build_diet_references.R", algo = "sha256"),
      sources = do.call(rbind, manifest)
    )
    result
  }
  .nhanes_diet_references <- list(
    dash = make_reference(dash_total, "dash", "essential8_fung_fped_v1", c(8, 40)),
    hei2015 = make_reference(hei_total, "hei2015", "hei2015_individual_two_recall_v1", c(0, 100))
  )
  # The eight DASH intake quintiles describe this specific index construction.
  # They are reproducibility metadata, not a new default raw-intake API.
  .nhanes_diet_references$dash$provenance$component_cutpoints <-
    component_cutpoints[setdiff(names(component_cutpoints), "total")]
  if (verify) {
    stored <- new.env()
    load("R/sysdata.rda", stored)
    for (method in names(.nhanes_diet_references)) {
      old <- stored$.nhanes_diet_references[[method]]
      new <- .nhanes_diet_references[[method]]
      stopifnot(identical(old[c("p25", "p50", "p75", "p95")],
                          new[c("p25", "p50", "p75", "p95")]),
                identical(old$provenance$n_by_cycle, new$provenance$n_by_cycle))
      stopifnot(identical(old$provenance$sources, new$provenance$sources))
    }
    message("Rebuilt cutpoints and sample counts match the packaged references.")
  } else {
    save(.nhanes_diet_references, file = "R/sysdata.rda", version = 2, compress = "xz")
    utils::write.csv(do.call(rbind, manifest), "data-raw/source-manifest.csv", row.names = FALSE)
    message("Saved compact references for ", nrow(cohort), " adult participants.")
  }
  print(lapply(.nhanes_diet_references, function(x) x[c("p25", "p50", "p75", "p95")]))
  invisible(.nhanes_diet_references)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  cache <- if (length(args) && args[1] != "--verify") args[1] else "tmp/nhanes-cache"
  build_diet_references(cache, verify = "--verify" %in% args)
}
