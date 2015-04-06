## siminf, a framework for stochastic disease spread simulations
## Copyright (C) 2015  Pavol Bauer
## Copyright (C) 2015  Stefan Engblom
## Copyright (C) 2015  Stefan Widgren
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

##' Check if wholenumbers
##'
##' Check that all values are wholenumbers, see example in integer {base}
##' @param x Value to check
##' @param tol Tolerance of the check
##' @return logical vector
##' @keywords internal
is_wholenumber <- function(x, tol = .Machine$double.eps^0.5)
{
    abs(x - round(x)) < tol
}

##' Class \code{"external_events"}
##'
##' Class to handle the external events
##' @section Slots:
##' \describe{
##'   \item{E}{
##'     Sparse matrix of object class \code{"\linkS4class{dgCMatrix}"}.
##'     Each row corresponds to one state in the compartment model. The
##'     non-zero entries in a column indicates the states to select and
##'     include in an event.  For the events \code{EXIT_EVENT},
##'     \code{INTERNAL_TRANSFER_EVENT} and \code{EXTERNAL_TRANSFER_EVENT},
##'     a non-zero entry in element \code{i} of select column \code{j}
##'     indicate the compartments to sample individuals from.  For the
##'     \code{ENTER_EVENT}, all individuals enter first non-zero compartment,
##'     i.e. a non-zero entry in element \code{i} of select column \code{j}.
##'   }
##'   \item{S}{
##'     For the \code{INTERNAL_TRANSFER_EVENT}, a non-zero entry in
##'     element \code{i} of select column \code{j} in \code{E} indicate
##'     the compartments to sample individuals from. The value of element
##'     \code{i} of shift column \code{k} in \code{S} determines the
##'     target compartment. The target compartment for sampled individuals
##'     is given by adding the value.
##'   }
##'   \item{event}{
##'     Integer vector of length \code{len} with external events.
##'     The following four events exists; \code{EXIT_EVENT = 0},
##'     \code{ENTER_EVENT = 1}, \code{INTERNAL_TRANSFER_EVENT = 2}, and
##'     \code{EXTERNAL_TRANSFER_EVENT = 3}.
##'   }
##'   \item{time}{
##'     Integer vector of length \code{len} with the time for the event.
##'   }
##'   \item{node}{
##'     Integer vector of length \code{len}. The node of the event \code{i}.
##'   }
##'   \item{dest}{
##'     Integer vector of length \code{len}. The destination node for a
##'     \code{EXTERNAL_TRANSFER_EVENT}.
##'   }
##'   \item{n}{
##'     Integer vector of length \code{len}. The number of individuals in the
##'     event. n[i] >= 0.
##'   }
##'   \item{proportion}{
##'     Numeric vector of length \code{len}. If n[i] equals zero,
##'     then the number of individuals to sample is calculated by summing
##'     the number of individuals in the states determined by
##'     select[i] and multiplying with the proportion.
##'     0 <= proportion[i] <= 1.
##'   }
##'   \item{select}{
##'     Integer vector of length \code{len}. Column \code{j} in the event
##'     matrix \code{E} that determines the states to sample from.
##'   }
##'   \item{shift}{
##'     Integer vector of length \code{len}. Column j in the shift matrix
##'     \code{S} that determines how to shift the sampled states in an
##'     \code{INTERNAL_TRANSFER_EVENT}. Should be \code{-1} for the other
##'     event types.
##'   }
##'   \item{len}{
##'     Number of scheduled external events.
##'   }
##' }
##' @name external_events-class
##' @docType class
##' @keywords classes
##' @keywords methods
##' @import methods
##' @import Matrix
##' @export
setClass("external_events",
         slots = c(E          = "dgCMatrix",
                   S          = "dgCMatrix",
                   event      = "integer",
                   time       = "integer",
                   node       = "integer",
                   dest       = "integer",
                   n          = "integer",
                   proportion = "numeric",
                   select     = "integer",
                   shift      = "integer",
                   len        = "integer"),
         prototype = list(len = 0L),
         validity = function(object) {
             errors <- character()

             if (!identical(length(unique(c(length(object@event),
                                            length(object@time),
                                            length(object@node),
                                            length(object@dest),
                                            length(object@n),
                                            length(object@proportion),
                                            length(object@select),
                                            length(object@shift)))) , 1L)) {
                 errors <- c(errors, "All external events must have equal length.")
             }

             if (!identical(length(object@len), 1L)) {
                 errors <- c(errors,
                             "Length of len must be equal to one.")
             }

             if (!identical(length(object@event), object@len)) {
                 errors <- c(errors,
                             "Length of external events must be equal to len.")
             }

             if (!all(object@time > 0)) {
                 errors <- c(errors,
                             "time must be greater than 0")
             }

             if (any(object@event < 0, object@event > 3)) {
                 errors <- c(errors,
                             "event must be in the range 0 <= event <= 3")
             }

             if (any(object@proportion < 0, object@proportion > 1)) {
                 errors <- c(errors,
                             "prop must be in the range 0 <= prop <= 1")
             }

             if (any(object@select < 0, object@select >= dim(object@E)[2])) {
                 errors <- c(errors,
                             "select must be in the range 0 <= select < Nselect")
             }

             if (length(errors) == 0) TRUE else errors
         }
)

##' Create S4 class \code{external_events}
##'
##' The argument events must be a \code{data.frame} with the following
##' columns:
##' \itemize{
##'   \item{event}{
##'     The event type. The following four events exists;
##'     \code{EXIT_EVENT = 0}, \code{ENTER_EVENT = 1},
##'     \code{INTERNAL_TRANSFER_EVENT = 2}, and
##'     \code{EXTERNAL_TRANSFER_EVENT = 3}.
##'   }
##'   \item{time}{
##'     The time of the event.
##'   }
##'   \item{node}{
##'     The node of the event
##'   }
##'   \item{dest}{
##'     The destination node for a \code{EXTERNAL_TRANSFER_EVENT}.
##'   }
##'   \item{n}{
##'     The number of individuals in the event. n[i] >= 0.
##'   }
##'   \item{proportion}{
##'     If n[i] equals zero, then the number of individuals to sample
##'     is calculated by summing the number of individuals in the
##'     states determined by select[i] and multiplying with the
##'     proportion. 0 <= proportion[i] <= 1.
##'   }
##'   \item{select}{
##'     Column \code{j} in the event matrix \code{E} that determines
##'     the states to sample from.
##'   }
##'   \item{shift}{
##'     Column j in the shift matrix \code{S} that determines how to
##'     shift the sampled states in an \code{INTERNAL_TRANSFER_EVENT}.
##'     Should be \code{-1} for the other event types.
##'   }
##' }
##' @param E Sparse matrix of object class \code{"\linkS4class{dgCMatrix}"}
##'        that selects the states to include for sampling in an event.
##' @param S Sparse matrix of object class \code{"\linkS4class{dgCMatrix}"}
##'        that determines how to shift the states in an
##'        \code{INTERNAL_TRANSFER_EVENT}.
##' @param events A \code{data.frame} with events.
##' @return S4 class \code{external_events}
##' @export
external_events <- function(E      = NULL,
                            S      = NULL,
                            events = NULL)
{
    ## Check E
    if (is.null(E)) {
        if (!is.null(events))
            stop("events is not NULL when E is NULL")
        E <- new("dgCMatrix")
    }

    ## Check S
    if (is.null(S)) {
        if (!is.null(events))
            stop("events is not NULL when S is NULL")
        S <- new("dgCMatrix")
    }

    ## Check events
    if (is.null(events)) {
        events <- data.frame(event      = as.integer(),
                             time       = as.integer(),
                             node       = as.integer(),
                             dest       = as.integer(),
                             n          = as.integer(),
                             proportion = as.numeric(),
                             select     = as.integer(),
                             shift      = as.integer())
    }
    if (!is.data.frame(events))
        stop("events must be a data.frame")
    if (!identical(ncol(events), 8L))
        stop("Wrong dimension of events")
    if (!all(c("event", "time", "node", "dest", "n", "proportion", "select", "shift") %in% names(events)))
        stop("Missing columns in events")
    if (!is.numeric(events$event))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$time))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$node))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$dest))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$n))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$proportion))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$select))
        stop("Columns in events must be numeric")
    if (!is.numeric(events$shift))
        stop("Columns in events must be numeric")

    if (nrow(events)) {
        if (!all(is_wholenumber(events$event)))
            stop("Columns in events must be integer")
        if (!all(is_wholenumber(events$time)))
            stop("Columns in events must be integer")
        if (!all(is_wholenumber(events$node)))
            stop("Columns in events must be integer")
        if (!all(is_wholenumber(events$dest)))
            stop("Columns in events must be integer")
        if (!all(is_wholenumber(events$n)))
            stop("Columns in events must be integer")
        if (!all(is_wholenumber(events$select)))
            stop("Columns in events must be integer")
        if (!all(is_wholenumber(events$shift)))
            stop("Columns in events must be integer")
    }

    events <- events[order(events$time, events$event, events$select),]

    return(new("external_events",
               E          = E,
               S          = S,
               event      = as.integer(events$event),
               time       = as.integer(events$time),
               node       = as.integer(events$node),
               dest       = as.integer(events$dest),
               n          = as.integer(events$n),
               proportion = as.numeric(events$proportion),
               select     = as.integer(events$select),
               shift      = as.integer(events$shift),
               len        = nrow(events)))
}

##' Brief summary of \code{external_events}
##'
##' @aliases show,external_events-methods
##' @docType methods
##' @param object The external_events \code{object}
##' @return None (invisible 'NULL').
##' @keywords methods
##' @export
setMethod("show",
          signature(object = "external_events"),
          function (object)
          {
              cat("\nExternal events:\n")
              cat(sprintf("E: %i x %i\n", dim(object@E)[1], dim(object@E)[2]))
              cat(sprintf("S: %i x %i\n", dim(object@S)[1], dim(object@S)[2]))

              if (length(object@event)) {
                  cat(sprintf("event: 1 x %i\n", length(object@event)))
              } else {
                  cat("event: 0 x 0\n")
              }

              if (length(object@time)) {
                  cat(sprintf("time: 1 x %i\n", length(object@time)))
              } else {
                  cat("time: 0 x 0\n")
              }

              if (length(object@select)) {
                  cat(sprintf("select: 1 x %i\n", length(object@select)))
              } else {
                  cat("select: 0 x 0\n")
              }

              if (length(object@node)) {
                  cat(sprintf("node: 1 x %i\n", length(object@node)))
              } else {
                  cat("node: 0 x 0\n")
              }

              if (length(object@dest)) {
                  cat(sprintf("dest: 1 x %i\n", length(object@dest)))
              } else {
                  cat("dest: 0 x 0\n")
              }

              if (length(object@n)) {
                  cat(sprintf("n: 1 x %i\n", length(object@n)))
              } else {
                  cat("n: 0 x 0\n")
              }

              if (length(object@proportion)) {
                  cat(sprintf("proportion: 1 x %i\n", length(object@proportion)))
              } else {
                  cat("proportion: 0 x 0\n")
              }

              if (length(object@len)) {
                  cat(sprintf("len: %i\n", object@len[1]))
              } else {
                  cat("len: 0\n")
              }
          }
)
