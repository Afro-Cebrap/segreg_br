# Functions used to standardize log messages across the pipeline

# Logs an informational message with a timestamp
# Parameters:
#   ...: Text to concatenate and display
# Returns:
#   NULL. Displays the message in the console

log_info <- function(...) {
  message(sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

# Logs a successful operation with a timestamp
# Parameters:
#   ...: Text to concatenate and display
# Returns:
#   NULL. Displays the message in the console

log_success <- function(...) {
  message(sprintf("[%s] OK - %s", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

# Logs an error message with a timestamp and stops execution
# Parameters:
#   ...: Text to concatenate and display
# Returns:
#   NULL. Stops script execution and displays the message.
log_error <- function(...) {
  stop(
    sprintf("[%s] ERROR - %s", format(Sys.time(), "%H:%M:%S"), paste0(...)),
    call. = FALSE
  )
}