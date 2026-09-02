# Reusable helper functions.

preferred_tz <- c(
  "Europe/Berlin"
)

project_directories <- c(
  "data/source",
  "data/input",
  "data/derived",
  "results/tables",
  "results/models",
  "figures",
  "reports"
)

artifact_registry_file <- "metadata/artifacts.csv"
artifact_registry_columns <- c(
  "artifact",
  "state",
  "current_sha256",
  "last_checked_at",
  "last_checked_by",
  "last_changed_at",
  "last_change_detected_by"
)

required_project_packages <- c(
  "digest",
  "dplyr",
  "ggplot2",
  "here",
  "janitor",
  "jsonlite",
  "readr",
  "stringr",
  "tibble",
  "tidyr",
  "yaml"
)

assert_project_root <- function() {
  required_paths <- c(
    "renv.lock",
    "scripts/functions.R",
    "maize-yield-project.Rproj"
  )

  missing_paths <- required_paths[!file.exists(required_paths)]

  if (length(missing_paths) > 0) {
    stop(
      "Run this command from the maize-yield project root.\n",
      "Missing expected path(s): ",
      paste(missing_paths, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(normalizePath(".", mustWork = TRUE))
}

ensure_project_directories <- function() {
  for (directory in project_directories) {
    if (!dir.exists(directory)) {
      created <- dir.create(directory, recursive = TRUE)

      if (!isTRUE(created) && !dir.exists(directory)) {
        stop(
          "Could not create project directory: ",
          directory,
          call. = FALSE
        )
      }
    }
  }

  invisible(project_directories)
}

check_required_packages <- function(
  packages = required_project_packages
) {
  missing_packages <- packages[
    !vapply(
      packages,
      requireNamespace,
      quietly = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  if (length(missing_packages) > 0) {
    stop(
      "The project package environment is incomplete.\n",
      "Missing package(s): ",
      paste(missing_packages, collapse = ", "),
      "\nRun: Rscript scripts/setup.R",
      call. = FALSE
    )
  }

  invisible(packages)
}

artifact_path <- function(path) {
  path <- as.character(path)
  project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  absolute <- ifelse(
    grepl("^(/|[A-Za-z]:[/\\\\])", path),
    path,
    file.path(project_root, path)
  )
  normalized <- normalizePath(
    absolute,
    winslash = "/",
    mustWork = FALSE
  )
  prefix <- paste0(project_root, "/")
  ifelse(startsWith(normalized, prefix), substring(normalized, nchar(prefix) + 1L), normalized)
}

artifact_sha256 <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    return(NA_character_)
  }
  digest::digest(
    path,
    algo = "sha256",
    serialize = FALSE,
    file = TRUE
  )
}

read_artifact_registry <- function(
  registry_file = artifact_registry_file
) {
  if (!file.exists(registry_file)) {
    registry <- as.data.frame(
      setNames(
        replicate(
          length(artifact_registry_columns),
          character(),
          simplify = FALSE
        ),
        artifact_registry_columns
      ),
      stringsAsFactors = FALSE
    )
    return(registry)
  }

  registry <- read.csv(
    registry_file,
    colClasses = "character",
    na.strings = "",
    check.names = FALSE
  )
  missing_columns <- setdiff(artifact_registry_columns, names(registry))
  if (length(missing_columns) > 0) {
    stop(
      "Artifact registry is missing column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  registry[artifact_registry_columns]
}

check_artifact_state <- function(
  paths,
  checked_by,
  phase = c("before", "after"),
  registry_file = artifact_registry_file
) {
  phase <- match.arg(phase)
  paths <- unique(as.character(paths))
  paths <- paths[nzchar(paths)]
  if (length(paths) == 0) {
    return(invisible(data.frame()))
  }

  check_required_packages("digest")
  checked_at <- format(
    Sys.time(),
    tz = preferred_tz,
    format = "%Y-%m-%dT%H:%M:%SZ"
  )
  registry <- read_artifact_registry(registry_file)
  observations <- lapply(paths, function(path) {
    relative_path <- artifact_path(path)
    present <- file.exists(path) && !dir.exists(path)
    current_state <- if (present) "present" else "missing"
    current_sha256 <- if (present) artifact_sha256(path) else NA_character_
    existing_index <- match(relative_path, registry$artifact)

    if (is.na(existing_index)) {
      previous_state <- NA_character_
      previous_sha256 <- NA_character_
      changed <- TRUE
      registry[nrow(registry) + 1L, ] <<- list(
        relative_path,
        current_state,
        current_sha256,
        checked_at,
        checked_by,
        checked_at,
        checked_by
      )
    } else {
      previous_state <- registry$state[[existing_index]]
      previous_sha256 <- registry$current_sha256[[existing_index]]
      changed <- !identical(previous_state, current_state) ||
        !identical(previous_sha256, current_sha256)

      registry$state[[existing_index]] <<- current_state
      registry$current_sha256[[existing_index]] <<- current_sha256
      registry$last_checked_at[[existing_index]] <<- checked_at
      registry$last_checked_by[[existing_index]] <<- checked_by
      if (changed) {
        registry$last_changed_at[[existing_index]] <<- checked_at
        registry$last_change_detected_by[[existing_index]] <<- checked_by
      }
    }

    data.frame(
      artifact = relative_path,
      phase = phase,
      state = current_state,
      change = if (changed) "changed" else "unchanged",
      stringsAsFactors = FALSE
    )
  })

  registry <- registry[order(registry$artifact), artifact_registry_columns]
  registry_directory <- dirname(registry_file)
  if (!dir.exists(registry_directory)) {
    dir.create(registry_directory, recursive = TRUE)
  }
  temporary_file <- paste0(registry_file, ".part")
  write.csv(registry, temporary_file, row.names = FALSE, na = "")
  if (file.exists(registry_file) && !file.remove(registry_file)) {
    stop("Could not replace artifact registry: ", registry_file, call. = FALSE)
  }
  if (!file.rename(temporary_file, registry_file)) {
    stop("Could not move artifact registry into place: ", registry_file, call. = FALSE)
  }

  observations <- do.call(rbind, observations)
  message(
    "Artifact state checked ", phase, " ", checked_by, ": ",
    paste(
      paste0(observations$artifact, " [", observations$state, ", ",
             observations$change, "]"),
      collapse = "; "
    )
  )
  invisible(observations)
}

safe_log <- function(x) {
  ifelse(is.na(x) | x <= 0, NA_real_, log(x))
}

mae_vec <- function(truth, estimate) {
  mean(abs(truth - estimate), na.rm = TRUE)
}

rmse_vec <- function(truth, estimate) {
  sqrt(mean((truth - estimate)^2, na.rm = TRUE))
}
