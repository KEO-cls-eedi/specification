#!/usr/bin/env sh

# Change this to the path to plantuml.jar
CLS_EEDI_PLANTUML_JAR_PATH="/usr/share/plantuml/plantuml.jar"

CLS_EEDI_PLANTUML_JAR_PATH=${CLS_EEDI_PLANTUML_JAR_PATH} \
    doxygen ./doxygen.conf

cp -r schemas/* out/html
