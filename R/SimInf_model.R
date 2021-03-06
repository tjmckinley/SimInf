## This file is part of SimInf, a framework for stochastic
## disease spread simulations.
##
## Copyright (C) 2015 Pavol Bauer
## Copyright (C) 2017 -- 2019 Robin Eriksson
## Copyright (C) 2015 -- 2019 Stefan Engblom
## Copyright (C) 2015 -- 2019 Stefan Widgren
##
## SimInf is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## SimInf is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.

##' Class \code{"SimInf_model"}
##'
##' Class to handle the siminf data model
##' @section Slots:
##' \describe{
##'   \item{G}{
##'     Dependency graph that indicates the transition rates that need
##'     to be updated after a given state transition has occured.
##'     A non-zero entry in element \code{G[i, i]} indicates that transition
##'     rate \code{i} needs to be recalculated if the state transition
##'     \code{j} occurs. Sparse matrix (\eqn{Nt \times Nt}) of object class
##'     \code{\linkS4class{dgCMatrix}}.
##'   }
##'   \item{S}{
##'     Each column corresponds to a state transition, and execution
##'     of state transition \code{j} amounts to adding the \code{S[,
##'     j]} column to the state vector \code{u[, i]} of node \emph{i}
##'     where the transition occurred. Sparse matrix (\eqn{Nc \times
##'     Nt}) of object class \code{\linkS4class{dgCMatrix}}.
##'   }
##'   \item{U}{
##'     The result matrix with the number of individuals in each
##'     compartment in every node. \code{U[, j]} contains the number
##'     of individuals in each compartment at
##'     \code{tspan[j]}. \code{U[1:Nc, j]} contains the number of
##'     individuals in node 1 at \code{tspan[j]}. \code{U[(Nc + 1):(2
##'     * Nc), j]} contains the number of individuals in node 2 at
##'     \code{tspan[j]} etc. Integer matrix (\eqn{N_n N_c \times}
##'     \code{length(tspan)}).
##'   }
##'   \item{U_sparse}{
##'     If the model was configured to write the solution to a sparse
##'     matrix (\code{dgCMatrix}) the \code{U_sparse} contains the data
##'     and \code{U} is empty. The layout of the data in \code{U_sparse}
##'     is identical to \code{U}. Please note that \code{U_sparse}
##'     is numeric and \code{U} is integer.
##'   }
##'   \item{V}{
##'     The result matrix for the real-valued continuous
##'     state. \code{V[, j]} contains the real-valued state of the
##'     system at \code{tspan[j]}. Numeric matrix
##'     (\eqn{N_n}\code{dim(ldata)[1]} \eqn{\times}
##'     \code{length(tspan)}).
##'   }
##'   \item{V_sparse}{
##'     If the model was configured to write the solution to a sparse
##'     matrix (\code{dgCMatrix}) the \code{V_sparse} contains the data
##'     and \code{V} is empty. The layout of the data in \code{V_sparse}
##'     is identical to \code{V}.
##'   }
##'   \item{ldata}{
##'     A matrix with local data for the nodes. The column \code{ldata[, j]}
##'     contains the local data vector for the node \code{j}. The local
##'     data vector is passed as an argument to the transition rate
##'     functions and the post time step function.
##'   }
##'   \item{gdata}{
##'     A numeric vector with global data that is common to all nodes.
##'     The global data vector is passed as an argument to the
##'     transition rate functions and the post time step function.
##'   }
##'   \item{tspan}{
##'     A vector of increasing time points where the state of each node is
##'     to be returned.
##'   }
##'   \item{u0}{
##'     The initial state vector (\eqn{N_c \times N_n}) with
##'     the number of individuals in each compartment in every node.
##'   }
##'   \item{v0}{
##'      The initial value for the real-valued continuous state.
##'      Numeric matrix (\code{dim(ldata)[1]} \eqn{\times N_n}).
##'   }
##'   \item{events}{
##'     Scheduled events \code{\linkS4class{SimInf_events}}
##'   }
##'   \item{C_code}{
##'     Character vector with optional model C code. If non-empty, the
##'     C code is written to a temporary C-file when the \code{run}
##'     method is called.  The temporary C-file is compiled and the
##'     resulting DLL is dynamically loaded. The DLL is unloaded and
##'     the temporary files are removed after running the model.
##'   }
##' }
##' @include SimInf_events.R
##' @export
##' @importFrom methods validObject
##' @importClassesFrom Matrix dgCMatrix
setClass("SimInf_model",
         slots = c(G        = "dgCMatrix",
                   S        = "dgCMatrix",
                   U        = "matrix",
                   U_sparse = "dgCMatrix",
                   ldata    = "matrix",
                   gdata    = "numeric",
                   tspan    = "numeric",
                   u0       = "matrix",
                   V        = "matrix",
                   V_sparse = "dgCMatrix",
                   v0       = "matrix",
                   events   = "SimInf_events",
                   C_code   = "character"))

## Check if the SimInf_model object is valid.
valid_SimInf_model_object <- function(object) {
    ## Check events
    validObject(object@events)

    ## Check tspan.
    if (!is.double(object@tspan)) {
        return("Input time-span must be a double vector.")
    } else if (any(length(object@tspan) < 2,
                   any(diff(object@tspan) <= 0),
                   any(is.na(object@tspan)))) {
        return("Input time-span must be an increasing vector.")
    }

    ## Check u0.
    if (!identical(storage.mode(object@u0), "integer"))
        return("Initial state 'u0' must be an integer matrix.")
    if (any(object@u0 < 0L))
        return("Initial state 'u0' has negative elements.")
    Nn_u0 <- dim(object@u0)[2]

    ## Check U.
    if (!identical(storage.mode(object@U), "integer"))
        return("Output state 'U' must be an integer matrix.")
    if (any(object@U < 0L) || any(object@U_sparse < 0, na.rm = TRUE))
        return("Output state 'U' has negative elements.")

    ## Check v0.
    if (!identical(storage.mode(object@v0), "double"))
        return("Initial model state 'v0' must be a double matrix.")
    if ((dim(object@v0)[1] > 0)) {
        r <- rownames(object@v0)
        if (is.null(r) || any(nchar(r) == 0))
            return("'v0' must have rownames.")
        if (!identical(dim(object@v0)[2], Nn_u0))
            return("The number of nodes in 'u0' and 'v0' must match.")
    }

    ## Check V.
    if (!identical(storage.mode(object@V), "double"))
        return("Output model state 'V' must be a double matrix.")

    ## Check S.
    if (!all(is_wholenumber(object@S@x)))
        return("'S' matrix must be an integer matrix.")

    ## Check that S and events@E have identical compartments
    if ((dim(object@S)[1] > 0) && (dim(object@events@E)[1] > 0)) {
        if (is.null(rownames(object@S)) || is.null(rownames(object@events@E)))
            return("'S' and 'E' must have rownames matching the compartments.")
        if (!identical(rownames(object@S), rownames(object@events@E)))
            return("'S' and 'E' must have identical compartments.")
    }

    ## Check G.
    Nt <- dim(object@S)[2]
    if (!identical(dim(object@G), c(Nt, Nt)))
        return("Wrong size of dependency graph.")

    ## Check that transitions exist in G.
    transitions <- rownames(object@G)
    if (is.null(transitions))
        return("'G' must have rownames that specify transitions.")
    transitions <- sub("[[:space:]]*$", "", transitions)
    transitions <- sub("^[[:space:]]*", "", transitions)
    if (!all(nchar(transitions) > 0))
        return("'G' must have rownames that specify transitions.")

    ## Check that the format of transitions are valid:
    ## For example: "X1 + X2 + ... + Xn -> Y1 + Y2 + ... + Yn"
    ## or
    ## For example: "X1 + X2 + ... + Xn -> propensity -> Y1 + Y2 + ... + Yn"
    ## is expected, where X2, ..., Xn and Y2, ..., Yn are optional.
    transitions <- strsplit(transitions, split = "->", fixed = TRUE)
    if (any(sapply(transitions, length) < 2))
        return("'G' rownames have invalid transitions.")

    ## Check that transitions and S have identical compartments.
    transitions <- unlist(lapply(transitions, function(x) {
        c(x[1], x[length(x)])
    }))
    transitions <- unlist(strsplit(transitions, split = "+", fixed = TRUE))
    transitions <- sub("[[:space:]]*$", "", transitions)
    transitions <- sub("^[[:space:]]*", "", transitions)
    transitions <- unique(transitions)
    transitions <- transitions[transitions != "@"]
    transitions <- sub("^[[:digit:]]+[*]", "", transitions)
    if (!all(transitions %in% rownames(object@S)))
        return("'G' and 'S' must have identical compartments.")

    ## Check ldata.
    if (!is.double(object@ldata))
        return("'ldata' matrix must be a double matrix.")
    Nn_ldata <- dim(object@ldata)[2]
    if (Nn_ldata > 0 && !identical(Nn_ldata, Nn_u0))
        return("The number of nodes in 'u0' and 'ldata' must match.")

    ## Check gdata.
    if (!is.double(object@gdata))
        return("'gdata' must be a double vector.")

    TRUE
}

## Assign the function as the validity method for the class.
setValidity("SimInf_model", valid_SimInf_model_object)

## Utility function to coerce the data.frame to a transposed matrix.
as_t_matrix <- function(x) {
    n_col <- ncol(x)
    n_row <- nrow(x)
    lbl <- colnames(x)
    x <- t(data.matrix(x))
    attributes(x) <- NULL
    dim(x) <- c(n_col, n_row)
    rownames(x) <- lbl
    x
}

##' Create a \code{SimInf_model}
##'
##' @template G-param
##' @template S-param
##' @template U-param
##' @template ldata-param
##' @template gdata-param
##' @template tspan-param
##' @param u0 The initial state vector. Either a matrix (\eqn{N_c
##'     \times N_n}) or a a \code{data.frame} with the number of
##'     individuals in each compartment in every node.
##' @param events A \code{data.frame} with the scheduled events.
##' @param V The result matrix for the real-valued continous
##'     compartment state (\eqn{N_n}\code{dim(ldata)[1]} \eqn{\times}
##'     \code{length(tspan)}).  \code{V[, j]} contains the real-valued
##'     state of the system at \code{tspan[j]}.
##' @param v0 The initial continuous state vector in every node.
##'     (\code{dim(ldata)[1]} \eqn{\times N_N}). The continuous state
##'     vector is updated by the specific model during the simulation
##'     in the post time step function.
##' @param E Sparse matrix to handle scheduled events, see
##'     \code{\linkS4class{SimInf_events}}.
##' @param N Sparse matrix to handle scheduled events, see
##'     \code{\linkS4class{SimInf_events}}.
##' @param C_code Character vector with optional model C code. If
##'     non-empty, the C code is written to a temporary C-file when
##'     the \code{run} method is called.  The temporary C-file is
##'     compiled and the resulting DLL is dynamically loaded. The DLL
##'     is unloaded and the temporary files are removed after running
##'     the model.
##' @return \linkS4class{SimInf_model}
##' @export
##' @importFrom methods as
##' @importFrom methods is
##' @importFrom methods new
SimInf_model <- function(G,
                         S,
                         tspan,
                         events = NULL,
                         ldata  = NULL,
                         gdata  = NULL,
                         U      = NULL,
                         u0     = NULL,
                         v0     = NULL,
                         V      = NULL,
                         E      = NULL,
                         N      = NULL,
                         C_code = NULL) {
    ## Check u0
    if (is.null(u0))
        stop("'u0' is NULL.", call. = FALSE)
    if (is.data.frame(u0))
        u0 <- as_t_matrix(u0)
    if (!all(is.matrix(u0), is.numeric(u0)))
        stop("u0 must be an integer matrix.", call. = FALSE)
    if (!is.integer(u0)) {
        if (!all(is_wholenumber(u0)))
            stop("u0 must be an integer matrix.", call. = FALSE)
        storage.mode(u0) <- "integer"
    }

    ## Check G
    if (!is.null(G)) {
        if (!is(G, "dgCMatrix"))
            G <- as(G, "dgCMatrix")
    }

    ## Check S
    if (!is.null(S)) {
        if (!is(S, "dgCMatrix"))
            S <- as(S, "dgCMatrix")
    }

    ## Check ldata
    if (is.null(ldata))
        ldata <- matrix(numeric(0), nrow = 0, ncol = 0)
    if (is.data.frame(ldata))
        ldata <- as_t_matrix(ldata)
    if (is.integer(ldata))
        storage.mode(ldata) <- "double"

    ## Check gdata
    if (is.null(gdata))
        gdata <- numeric(0)
    if (is.data.frame(gdata)) {
        if (!identical(nrow(gdata), 1L)) {
            stop("When 'gdata' is a data.frame, it must have one row.",
                 call. = FALSE)
        }
        gdata <- unlist(gdata)
    }

    ## Check U
    if (is.null(U)) {
        U <- matrix(integer(0), nrow = 0, ncol = 0)
    } else {
        if (!is.integer(U)) {
            if (!all(is_wholenumber(U)))
                stop("U must be an integer.", call. = FALSE)
            storage.mode(U) <- "integer"
        }

        if (!is.matrix(U)) {
            if (!identical(length(U), 0L))
                stop("U must be equal to 0 x 0 matrix.", call. = FALSE)
            dim(U) <- c(0, 0)
        }
    }

    ## Check v0
    if (is.null(v0)) {
        v0 <- matrix(numeric(0), nrow = 0, ncol = 0)
    } else {
        if (is.data.frame(v0))
            v0 <- as_t_matrix(v0)
        if (!all(is.matrix(v0), is.numeric(v0)))
            stop("v0 must be a numeric matrix.", call. = FALSE)

        if (!identical(storage.mode(v0), "double"))
            storage.mode(v0) <- "double"
    }

    ## Check V
    if (is.null(V)) {
        V <- matrix(numeric(0), nrow = 0, ncol = 0)
    } else {
        if (!is.numeric(V))
            stop("V must be numeric.")

        if (!identical(storage.mode(V), "double"))
            storage.mode(V) <- "double"

        if (!is.matrix(V)) {
            if (!identical(length(V), 0L))
                stop("V must be equal to 0 x 0 matrix.", call. = FALSE)
            dim(V) <- c(0, 0)
        }
    }

    ## Check tspan
    if (is(tspan, "Date")) {
        ## Coerce the date vector to a numeric vector as days, where
        ## tspan[1] becomes the day of the year of the first year of
        ## the tspan date vector. The dates are added as names to the
        ## numeric vector.
        t0 <- as.numeric(as.Date(format(tspan[1], "%Y-01-01"))) - 1
        tspan_lbl <- format(tspan, "%Y-%m-%d")
        tspan <- as.numeric(tspan) - t0
        names(tspan) <- tspan_lbl
    } else {
        t0 <- NULL
    }
    storage.mode(tspan) <- "double"

    ## Check events
    if (!any(is.null(events), is.data.frame(events)))
        stop("'events' must be NULL or a data.frame.", call. = FALSE)
    events <- SimInf_events(E = E, N = N, events = events, t0 = t0)

    ## Check C code
    if (is.null(C_code))
        C_code <- character(0)

    new("SimInf_model",
        G      = G,
        S      = S,
        U      = U,
        ldata  = ldata,
        gdata  = gdata,
        tspan  = tspan,
        u0     = u0,
        v0     = v0,
        V      = V,
        events = events,
        C_code = C_code)
}

##' Extract number of nodes in a model
##'
##' Extract number of nodes in a model.
##' @param model the \code{model} object to extract the number of
##'     nodes from.
##' @return the number of nodes in the model.
##' @export
##' @examples
##' ## Create an 'SIR' model with 100 nodes, with 99 susceptible,
##' ## 1 infected and 0 recovered in each node.
##' u0 <- data.frame(S = rep(99, 100), I = rep(1, 100), R = rep(0, 100))
##' model <- SIR(u0 = u0, tspan = 1:10, beta = 0.16, gamma = 0.077)
##'
##' ## Display the number of nodes in the model.
##' Nn(model)
Nn <- function(model) {
    check_model_argument(model)
    dim(model@u0)[2]
}

## Number of compartments
Nc <- function(model) {
    check_model_argument(model)
    dim(model@S)[1]
}

## Number of transitions
Nt <- function(model) {
    check_model_argument(model)
    dim(model@G)[1]
}

## Number of continuous state variables
Nd <- function(model) {
    check_model_argument(model)
    dim(model@v0)[1]
}

##' Extract global data from a \code{SimInf_model} object
##'
##' The global data is a numeric vector that is common to all nodes.
##' The global data vector is passed as an argument to the transition
##' rate functions and the post time step function.
##' @param model The \code{model} to get global data from.
##' @return a numeric vector
##' @export
##' @examples
##' ## Create an SIR model
##' model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
##'              tspan = 1:5, beta = 0.16, gamma = 0.077)
##'
##' ## Set 'beta' to a new value
##' gdata(model, "beta") <- 2
##'
##' ## Extract the global data vector that is common to all nodes
##' gdata(model)
gdata <- function(model) {
    check_model_argument(model)
    model@gdata
}

##' Set a global data parameter for a \code{SimInf_model} object
##'
##' The global data is a numeric vector that is common to all nodes.
##' The global data vector is passed as an argument to the transition
##' rate functions and the post time step function.
##' @param model The \code{model} to set a global model parameter for.
##' @param parameter The name of the parameter to set.
##' @param value A numeric value.
##' @return a \code{SimInf_model} object
##' @export
##' @examples
##' ## Create an SIR model
##' model <- SIR(u0 = data.frame(S = 99, I = 1, R = 0),
##'              tspan = 1:5, beta = 0.16, gamma = 0.077)
##'
##' ## Set 'beta' to a new value
##' gdata(model, "beta") <- 2
##'
##' ## Extract the global data vector that is common to all nodes
##' gdata(model)
"gdata<-" <- function(model, parameter, value) {
    check_model_argument(model)

    ## Check paramter argument
    if (missing(parameter))
        stop("Missing 'parameter' argument.", call. = FALSE)
    if (!is.character(parameter))
        stop("'parameter' argument must be a character.", call. = FALSE)

    ## Check value argument
    if (missing(value))
        stop("Missing 'value' argument.", call. = FALSE)
    if (!is.numeric(value))
        stop("'value' argument must be a numeric.", call. = FALSE)

    model@gdata[parameter] <- value

    model
}

##' Extract local data from a node
##'
##' The local data is a numeric vector that is specific to a node.
##' The local data vector is passed as an argument to the transition
##' rate functions and the post time step function.
##' @param model The \code{model} to get local data from.
##' @param node index to node to extract local data from.
##' @return a numeric vector
##' @export
##' @examples
##' ## Create an 'SISe' model with 1600 nodes.
##' model <- SISe(u0 = u0_SISe(), tspan = 1:100, events = events_SISe(),
##'               phi = 0, upsilon = 1.8e-2, gamma = 0.1, alpha = 1,
##'               beta_t1 = 1.0e-1, beta_t2 = 1.0e-1, beta_t3 = 1.25e-1,
##'               beta_t4 = 1.25e-1, end_t1 = c(91, 101), end_t2 = c(182, 185),
##'               end_t3 = c(273, 275), end_t4 = c(365, 360), epsilon = 0)
##'
##' ## Display local data from the first two nodes.
##' ldata(model, node = 1)
##' ldata(model, node = 2)
ldata <- function(model, node) {
    check_model_argument(model)

    ## Check node argument
    if (missing(node))
        stop("Missing 'node' argument.", call. = FALSE)
    if (!is.numeric(node) || !identical(length(node), 1L) || node < 1)
        stop("Invalid 'node' argument.", call. = FALSE)

    model@ldata[, node]
}
