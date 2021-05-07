#!/bin/bash

function spacer {
    printf "$1*** *** *** *** *** $3 *** *** *** *** ***$2"
}

function log_info() {
    echo -e "\033[32m---\033[0m $1"
}

function log_warning() {
    echo -e "\033[33m!!!\033[0m $1"
}

function log_error() {
    echo -e "\033[31m###\033[0m $1"
}