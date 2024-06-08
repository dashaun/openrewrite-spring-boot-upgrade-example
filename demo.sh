#!/usr/bin/env bash

TEMP_DIR="upgrade-example"
noClear=""

# Splain'r How this werks!
function usage() {
  echo ""
  echo "Usage: $0 -Runs SpringBoot demo via demo.sh" 
  echo ""
  echo ""
  echo "Demos Include: "
  echo " -SpringBoot Upgrade."
  echo " -Comparision of Native Images."
  echo ""
  echo "" 
  echo "Options: "
  echo ""
  echo "   -noClear  -Does not clear screen between talking points. Allows full-scrollback."
  echo ""
  echo ""
  echo "Example:  $0 -noClear"
  echo ""
  echo ""
  echo ""    
}


if [  "$1" == "-H" ] || [ "$1" == "-h" ] || [ "$1" == "--H" ] || [ "$1" == "--h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ]
	then
		usage
		exit 10
fi		
	
if [ "$1" == "-noClear" ] 
	then
		noClear="Y"
fi		

	
# Load helper functions and set initial variables

returnVal=99
vendir --version &> /dev/null	
returnVal=$?
	
if [ $returnVal -ne 0 ]; then
  echo "vendir not found. Please install vendir first."	
	exit 1
fi

returnVal=99
http --version &> /dev/null	
returnVal=$?
	
if [ $returnVal -ne 0 ]; then
  echo "httpie not found. Please install httpie first."	
	exit 1
fi

vendir sync
. ./vendir/demo-magic/demo-magic.sh
export TYPE_SPEED=100
export DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
PROMPT_TIMEOUT=5


# Stop ANY & ALL Java Process...they could be Springboot running on our ports!
function cleanUp {
	local npid=""

  npid=$(pgrep java)
  
 	if [ "$npid" != "" ] 
		then
  		
  		displayMessage "*** Stopping Any Previous Existing SpringBoot Apps..."		
			
			while [ "$npid" != "" ]
			do
				echo "***KILLING OFF The Following: $npid..."
		  	pei "kill -9 $npid"
				npid=$(pgrep java)
			done  
		
	fi
}

# Function to pause and clear [ or not ] the screen
function talkingPoint() {
  wait
  
	if [ "$noClear" != "Y" ] 
		then
			clear
	fi		

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
  sdk update
  sdk install java 8.0.412-librca
  sdk install java 23.1.2.r21-nik
}

# Prepare the working directory
function init {
  rm -rf "$TEMP_DIR"
  mkdir "$TEMP_DIR"
  cd "$TEMP_DIR" || exit
  
	if [ "$noClear" != "Y" ] 
		then
			clear
	fi		
}

# Switch to Java 8 and display version
function useJava8 {
  displayMessage "Use Java 8, this is for educational purposes only, don't do this at home! (I have jokes.)"
  pei "sdk use java 8.0.412-librca"
  pei "java -version"
}

# Switch to Java 21 and display version
function useJava21 {
  displayMessage "Switch to Java 21 for Spring Boot 3"
  pei "sdk use java 23.1.2.r21-nik"
  pei "java -version"
}

# Create a simple Spring Boot application
function cloneApp {
  displayMessage "Clone a Spring Boot 2.6.0 application"
  pei "git clone https://github.com/dashaun/hello-spring-boot-2-6.git ./"
}

# Start the Spring Boot application
function springBootStart {
  displayMessage "Start the Spring Boot application, Wait For It...."
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
  pei "while ! http :8080/actuator/health 2>/dev/null; do sleep 1; done"
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

# Upgrade the application to Spring Boot 3.3
function rewriteApplication {
  displayMessage "Upgrade to Spring Boot 3.3"
  pei "./mvnw -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST -Drewrite.activeRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_3"
}

# Build a native image of the application
function buildNative {
  displayMessage "Build a native image with AOT"
  pei "./mvnw -Pnative native:compile"
}

# Start the native image
function startNative {
  displayMessage "Start the native image"
  pei "./target/hello-spring 2>&1 | tee nativeWith3.3.log &"
}

# Stop the native image
function stopNative {
  displayMessage "Stop the native image"
  local npid=$(pgrep hello-spring)
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
  grep -o 'Started HelloSpringApplication in .*' < java8with2.6.log
  echo "The process was using $(cat java8with2.6.log2) megabytes"
  echo ""
  echo ""
  echo "Spring Boot 3.3 with Java 21"
  grep -o 'Started HelloSpringApplication in .*' < java21with3.3.log
  echo "The process was using $(cat java21with3.3.log2) megabytes"
  echo ""
  echo ""
  echo "Spring Boot 3.3 with AOT processing, native image"
  grep -o 'Started HelloSpringApplication in .*' < nativeWith3.3.log
  echo "The process was using $(cat nativeWith3.3.log2) megabytes"
  echo ""
  echo ""
  MEM1="$(grep '\S' java8with2.6.log2)"
  MEM2="$(grep '\S' java21with3.3.log2)"
  MEM3="$(grep '\S' nativeWith3.3.log2)"
  echo ""
  echo "The Spring Boot 3.3 with Java 21 version is using $(bc <<< "scale=2; ${MEM2}/${MEM1}*100")% of the original footprint"
  echo "The Spring Boot 3.3 with AOT processing version is using $(bc <<< "scale=2; ${MEM3}/${MEM1}*100")% of the original footprint"
}

function statsSoFarTable {
  displayMessage "Comparison of memory usage and startup times"
  echo ""

  # Headers
  printf "%-35s %-25s %-15s %s\n" "Configuration" "Startup Time (seconds)" "(MB) Used" "(MB) Savings"
  echo "--------------------------------------------------------------------------------------------"

  # Spring Boot 2.6 with Java 8
  #STARTUP1=$(sed -nE 's/.* in ([0-9]+\.[0-9]+) seconds.*/\1/p' < java8with2.6.log)
  #STARTUP1=$(grep -o 'Started HelloSpringApplication in .*' < java8with2.6.log)
  MEM1=$(cat java8with2.6.log2)
  START1=$(startupTime 'java8with2.6.log')
  printf "%-35s %-25s %-15s %s\n" "Spring Boot 2.6 with Java 8" "$START1" "$MEM1" "-"

  # Spring Boot 3.3 with Java 21
  #STARTUP2=$(grep -o 'Started HelloSpringApplication in .*' < java21with3.3.log)
  MEM2=$(cat java21with3.3.log2)
  PERC2=$(bc <<< "scale=2; 100 - ${MEM2}/${MEM1}*100")
  START2=$(startupTime 'java21with3.3.log')
  PERCSTART2=$(bc <<< "scale=2; 100 - ${START2}/${START1}*100")
  printf "%-35s %-25s %-15s %s \n" "Spring Boot 3.3 with Java 21" "$START2 ($PERCSTART2% faster)" "$MEM2" "$PERC2%"

  # Spring Boot 3.3 with AOT processing, native image
  #STARTUP3=$(grep -o 'Started HelloSpringApplication in .*' < nativeWith3.3.log)
  MEM3=$(cat nativeWith3.3.log2)
  PERC3=$(bc <<< "scale=2; 100 - ${MEM3}/${MEM1}*100")
  START3=$(startupTime 'nativeWith3.3.log')
  PERCSTART3=$(bc <<< "scale=2; 100 - ${START3}/${START1}*100")
  printf "%-35s %-25s %-15s %s \n" "Spring Boot 3.3 with AOT, native" "$START3 ($PERCSTART3% faster)" "$MEM3" "$PERC3%"


  echo "--------------------------------------------------------------------------------------------"
}

# Display Docker image statistics
function imageStats {
  pei "docker images | grep demo"
}

# Main execution flow

cleanUp
initSDKman
init
useJava8
talkingPoint
cloneApp
talkingPoint
springBootStart java8with2.6.log
talkingPoint
validateApp
talkingPoint
showMemoryUsage "$(jps | grep 'HelloSpringApplication' | cut -d ' ' -f 1)" java8with2.6.log2
talkingPoint
springBootStop
talkingPoint
rewriteApplication
talkingPoint
useJava21
talkingPoint
springBootStart java21with3.3.log
talkingPoint
validateApp
talkingPoint
showMemoryUsage "$(jps | grep 'HelloSpringApplication' | cut -d ' ' -f 1)" java21with3.3.log2
talkingPoint
springBootStop
talkingPoint
buildNative
talkingPoint
startNative
talkingPoint
validateApp
talkingPoint
showMemoryUsage "$(pgrep hello-spring)" nativeWith3.3.log2
talkingPoint
stopNative
talkingPoint
#statsSoFar
statsSoFarTable
