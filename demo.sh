#!/usr/bin/env bash

#set -x

. ./helper.sh
export TYPE_SPEED=100
export DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
TEMP_DIR=upgrade-example

function talkingPoint() {
  wait
  clear
}

function initSDKman() {
	if [[ -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
   	  source "$SDKMAN_DIR/bin/sdkman-init.sh"  
  else
      echo "SDKMAN_DIR is not set, using default location"
  	  source "$HOME/.sdkman/bin/sdkman-init.sh"  
	fi
	sdk install java 8.0.382-librca
	sdk install java 17.0.8-graalce  
  sdk install java 21-graalce
}

function init {
  rm -rf $TEMP_DIR
  mkdir $TEMP_DIR
  cd $TEMP_DIR || exit
  clear
}

function useJava8 {
  echo "#### Use Java 8, this is for educational purposes only"
  echo "#### Please, do not try this at home"
  echo ""
  pei "sdk use java 8.0.382-librca"
  pei "java -version" 
}

function useJava21 {
  echo "#### Because we have upgraded to Spring Boot 3"
  echo "#### We need to use, at least, Java 17"
  echo "#### Java 21 is GA so lets switch to Java 21"
  echo ""
  pei "sdk use java 21-graalce"
  pei "java -version"
}

function createAppWithInitializr {
  echo "#### Create a simple application with Spring Boot version 2.6.0"
  echo "#### Use the Spring Initializr (start.spring.io) with 'curl'"
  echo ""
  pei "export SPRING_BOOT_VERSION=2.6.0"
  pei "export DEPENDENCIES=web,actuator"
  pei "curl https://start.spring.io/starter.tgz -d dependencies=$DEPENDENCIES -d javaVersion=8 -d bootVersion=$SPRING_BOOT_VERSION -d type=maven-project | tar -xzf - || exit"
}

function springBootStart {
  echo "#### Start the application with the Spring Boot Maven Plugin"
  echo "#### The -q options is for quiet mode"
  echo ""
  pei "./mvnw -q clean package spring-boot:start -DskipTests 2>&1 | tee '$1' &"
}

function springBootStop {
  echo "#### We have the startup time and the memory footprint"
  echo "#### Stop the application using the Spring Boot Maven Plugin"
  echo ""
  pei "./mvnw spring-boot:stop -Dspring-boot.stop.fork"
}

function validateApp {
  echo "#### Check to actuator endpoint to see if it's up and running:"
  echo ""
  pei "http :8080/actuator/health"
}

function showMemoryUsage {
  echo "#### Use the process ID: $1"
  echo "#### to see how much memory its using"
  echo ""
  RSS=$(ps -o rss "$1" | tail -n1)
  RSS=$(bc <<< "scale=1; ${RSS}/1024")
  echo "The process was using ${RSS} megabytes"
  echo "${RSS}" >> "$2"
}

function rewriteApplication {
  echo "#### Use the OpenRewrite Maven Plugin"
  echo "#### Use the UpgradeSpringBoot_3_1 Recipe"
  echo "#### To upgrade to the latest version of Spring Boot"
  echo ""
  pei "./mvnw -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST -DactiveRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_1"
}

function buildNative {
  echo "#### Spring Framework 6 and Spring Boot 3 introduced Ahead of Time (AOT) Processing"
  echo "#### Use the native profile for AOT Processing"
  echo "#### It uses GraalVM to generate a statically-linked native binary"
  echo ""
  pei "./mvnw -Pnative native:compile"
}

function startNative {
  echo "#### Start the native image"
  echo ""
  pei "./target/demo 2>&1 | tee nativeWith3.1.log &"
}

function stopNative {
  echo "#### Stop the 'native image"
  echo ""
  pei "export NPID=$(pgrep demo)"
  pei "kill -9 $NPID"
}

function buildOCI {
  echo "#### Build an OCI Image using the JVM"
  echo "#### Build an OCI Image using GraalVM"
  echo "#### Tag the multi-architecture 'dashaun/builder:tiny' for use, instead of the default"
  pei ""
  pei "docker pull dashaun/builder:tiny && docker tag dashaun/builder:tiny paketobuildpacks/builder:tiny && docker tag dashaun/builder:tiny paketobuildpacks/builder:base"
  pei "./mvnw clean spring-boot:build-image -Dspring-boot.build-image.imageName=demo:0.0.1-JVM -Dspring-boot.build-image.createdDate=now"
  pei "./mvnw clean -Pnative spring-boot:build-image -Dspring-boot.build-image.imageName=demo:0.0.1-Native -Dspring-boot.build-image.createdDate=now"
  echo ""
}

function statsSoFar {
  echo "#### What did we see?"
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

function imageStats {
  pei "docker images | grep demo"
}

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
statsSoFar