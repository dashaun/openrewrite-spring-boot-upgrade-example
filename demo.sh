#!/usr/bin/env bash

# Load helper functions and set initial variables
vendir sync
. ./vendir/demo-magic/demo-magic.sh
export TYPE_SPEED=100
export DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
TEMP_DIR="upgrade-example"
PROMPT_TIMEOUT=5

# Function to pause and clear the screen
function talkingPoint() {
  wait
  clear
}

# Initialize SDKMAN and install required Java versions
function initSDKman() {
  local sdkman_init="${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
  if [[ -f "$sdkman_init" ]]; then
    source "$sdkman_init"
  else
    echo "SDKMAN not found. Please install SDKMAN first."
    exit 1
  fi
  sdk install java 8.0.382-librca
  sdk install java 17.0.8-graalce
  sdk install java 21-graalce
}

# Prepare the working directory
function init {
  rm -rf "$TEMP_DIR"
  mkdir "$TEMP_DIR"
  cd "$TEMP_DIR" || exit
  clear
}

# Switch to Java 8 and display version
function useJava8 {
  displayMessage "Use Java 8, this is for educational purposes only"
  pei "sdk use java 8.0.382-librca"
  pei "java -version" 
}

# Switch to Java 21 and display version
function useJava21 {
  displayMessage "Switch to Java 21 for Spring Boot 3"
  pei "sdk use java 21-graalce"
  pei "java -version"
}

# Create a simple Spring Boot application
function createAppWithInitializr {
  displayMessage "Create a Spring Boot 2.6.0 application"
  pei "export SPRING_BOOT_VERSION=2.6.0"
  pei "export DEPENDENCIES=web,actuator"
  pei "curl https://start.spring.io/starter.tgz -d dependencies=$DEPENDENCIES -d javaVersion=8 -d bootVersion=$SPRING_BOOT_VERSION -d type=maven-project | tar -xzf - || exit"
}

# Start the Spring Boot application
function springBootStart {
  displayMessage "Start the Spring Boot application"
  pei "./mvnw -q clean package spring-boot:start -DskipTests 2>&1 | tee '$1' &"
}

# Stop the Spring Boot application
function springBootStop {
  displayMessage "Stop the Spring Boot application"
  pei "./mvnw spring-boot:stop -Dspring-boot.stop.fork"
}

# Check the health of the application
function validateApp {
  displayMessage "Check application health"
  pei "http :8080/actuator/health"
}

# Display memory usage of the application
function showMemoryUsage {
  local pid=$1
  local log_file=$2
  local rss=$(ps -o rss= "$pid" | tail -n1)
  local mem_usage=$(bc <<< "scale=1; ${rss}/1024")
  echo "The process was using ${mem_usage} megabytes"
  echo "${mem_usage}" >> "$log_file"
}

# Upgrade the application to Spring Boot 3.1
function rewriteApplication {
  displayMessage "Upgrade to Spring Boot 3.1"
  pei "./mvnw -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST -DactiveRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_1"
}

# Build a native image of the application
function buildNative {
  displayMessage "Build a native image with AOT"
  pei "./mvnw -Pnative native:compile"
}

# Start the native image
function startNative {
  displayMessage "Start the native image"
  pei "./target/demo 2>&1 | tee nativeWith3.1.log &"
}

# Stop the native image
function stopNative {
  displayMessage "Stop the native image"
  local npid=$(pgrep demo)
  pei "kill -9 $npid"
}

# Build OCI images
function buildOCI {
  displayMessage "Build OCI images"
  pei "docker pull dashaun/builder:tiny && docker tag dashaun/builder:tiny paketobuildpacks/builder:tiny && docker tag dashaun/builder:tiny paketobuildpacks/builder:base"
  pei "./mvnw clean spring-boot:build-image -Dspring-boot.build-image.imageName=demo:0.0.1-JVM -Dspring-boot.build-image.createdDate=now"
  pei "./mvnw clean -Pnative spring-boot:build-image -Dspring-boot.build-image.imageName=demo:0.0.1-Native -Dspring-boot.build-image.createdDate=now"
}

# Display a message with a header
function displayMessage() {
  echo "#### $1"
  echo ""
}

function startupTime() {
  echo "$(sed -nE 's/.* in ([0-9]+\.[0-9]+) seconds.*/\1/p' < $1)"
}

# Compare and display statistics
function statsSoFar {
  displayMessage "Comparison of memory usage and startup times"
  echo ""
  echo "Spring Boot 2.6 with Java 8"
  grep -o 'Started DemoApplication in .*' < java8with2.6.log
  echo "The process was using $(cat java8with2.6.log2) megabytes"
  echo ""
  echo ""
  echo "Spring Boot 3.1 with Java 21"
  grep -o 'Started DemoApplication in .*' < java21with3.1.log
  echo "The process was using $(cat java21with3.1.log2) megabytes"
  echo ""
  echo ""
  echo "Spring Boot 3.1 with AOT processing, native image"
  grep -o 'Started DemoApplication in .*' < nativeWith3.1.log
  echo "The process was using $(cat nativeWith3.1.log2) megabytes"
  echo ""
  echo ""
  MEM1="$(grep '\S' java8with2.6.log2)"
  MEM2="$(grep '\S' java21with3.1.log2)"
  MEM3="$(grep '\S' nativeWith3.1.log2)"
  echo ""
  echo "The Spring Boot 3.1 with Java 21 version is using $(bc <<< "scale=2; ${MEM2}/${MEM1}*100")% of the original footprint"
  echo "The Spring Boot 3.1 with AOT processing version is using $(bc <<< "scale=2; ${MEM3}/${MEM1}*100")% of the original footprint" 
}

function statsSoFarTable {
  displayMessage "Comparison of memory usage and startup times"
  echo ""

  # Headers
  printf "%-35s %-25s %-15s %s\n" "Configuration" "Startup Time (seconds)" "(MB) Used" "(MB) Reduction"
  echo "--------------------------------------------------------------------------------------------"

  # Spring Boot 2.6 with Java 8
  #STARTUP1=$(sed -nE 's/.* in ([0-9]+\.[0-9]+) seconds.*/\1/p' < java8with2.6.log)
  #STARTUP1=$(grep -o 'Started DemoApplication in .*' < java8with2.6.log)
  MEM1=$(cat java8with2.6.log2)
  printf "%-35s %-25s %-15s %s\n" "Spring Boot 2.6 with Java 8" "$(startupTime 'java8with2.6.log')" "$MEM1" "-"

  # Spring Boot 3.1 with Java 21
  #STARTUP2=$(grep -o 'Started DemoApplication in .*' < java21with3.1.log)
  MEM2=$(cat java21with3.1.log2)
  PERC2=$(bc <<< "scale=2; 100 - ${MEM2}/${MEM1}*100")
  printf "%-35s %-25s %-15s %s \n" "Spring Boot 3.1 with Java 21" "$(startupTime 'java21with3.1.log')" "$MEM2" "$PERC2%"

  # Spring Boot 3.1 with AOT processing, native image
  #STARTUP3=$(grep -o 'Started DemoApplication in .*' < nativeWith3.1.log)
  MEM3=$(cat nativeWith3.1.log2)
  PERC3=$(bc <<< "scale=2; 100 - ${MEM3}/${MEM1}*100")
  printf "%-35s %-25s %-15s %s \n" "Spring Boot 3.1 with AOT, native" "$(startupTime 'nativeWith3.1.log')" "$MEM3" "$PERC3%"

  echo "--------------------------------------------------------------------------------------------"
}

# Display Docker image statistics
function imageStats {
  pei "docker images | grep demo"
}

# Main execution flow
initSDKman
init
useJava8
talkingPoint
createAppWithInitializr
talkingPoint
springBootStart java8with2.6.log
talkingPoint
validateApp
talkingPoint
showMemoryUsage "$(jps | grep 'DemoApplication' | cut -d ' ' -f 1)" java8with2.6.log2
talkingPoint
springBootStop
talkingPoint
rewriteApplication
talkingPoint
useJava21
talkingPoint
springBootStart java21with3.1.log
talkingPoint
validateApp
talkingPoint
showMemoryUsage "$(jps | grep 'DemoApplication' | cut -d ' ' -f 1)" java21with3.1.log2
talkingPoint
springBootStop
talkingPoint
buildNative
talkingPoint
startNative
talkingPoint
validateApp
talkingPoint
showMemoryUsage "$(pgrep demo)" nativeWith3.1.log2
talkingPoint
stopNative
talkingPoint
#statsSoFar
statsSoFarTable