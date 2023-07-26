#!/usr/bin/env bash

#set -x

. demo-magic.sh
export TYPE_SPEED=100
export DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
TEMP_DIR=upgrade-example

function talkingPoint() {
  wait
  clear
}

function initSDKman() {

	if [ -z "$SDKMAN_DIR" ]
	  then
   	  source "$SDKMAN_DIR/bin/sdkman-init.sh"  
  else
  	  source "$HOME/.sdkman/bin/sdkman-init.sh"  
	fi  
}

function createAppWithInitializr {
  # hide the evidence
  rm -rf $TEMP_DIR
  mkdir $TEMP_DIR
  cd $TEMP_DIR || exit
  clear
  pei "sdk use java 8.0.372-librca"
  pei "java -version"
  pei "export SPRING_BOOT_VERSION=2.6.0"
  pei "export DEPENDENCIES=web,actuator"
  pei "curl https://start.spring.io/starter.tgz -d dependencies=$DEPENDENCIES -d javaVersion=8 -d bootVersion=$SPRING_BOOT_VERSION -d type=maven-project | tar -xzf - || exit"
  talkingPoint
  pei "git init && git add . && git commit -m 'initializr'" 
}

function validateApp {
  pei "./mvnw -q clean package spring-boot:start -DskipTests"
  pei "http :8080/actuator/health"
  pei "vmmap $(jps | grep DemoApplication | cut -d ' ' -f 1) | grep Physical"
  pei "./mvnw spring-boot:stop -Dspring-boot.stop.fork"
}

function validateAppNoFork {
  pei "./mvnw -q clean package spring-boot:start -DskipTests"
  pei "http :8080/actuator/health"
  pei "vmmap $(jps | grep DemoApplication | cut -d ' ' -f 1) | grep Physical"
  talkingPoint
  pei "./mvnw spring-boot:stop"
  clear
}

function rewriteApplication {
  pe "./mvnw -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST -DactiveRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_1"
  pei "sdk use java 17.0.7-graalce"
  pei "java -version"
}

function nativeValidate {
  pe "./mvnw -Pnative native:compile -DskipTests"
  pei "./target/demo &"
  pei "http :8080/actuator/health"
  pei "export NPID=$(pgrep demo)"
  pei "vmmap $NPID | grep Physical"
  pei "kill -9 $NPID"
}

function quickNativeValidate {
  pei "GRAALVM_QUICK_BUILD=true ./mvnw -Pnative native:compile -DskipTests"
  pei "./target/demo &"
  pei "http :8080/actuator/health"
  pei "export NPID=$(pgrep demo)"
  pei "vmmap $NPID | grep Physical"
  pei "kill -9 $NPID"
}


initSDKman
createAppWithInitializr
talkingPoint
validateApp
talkingPoint
rewriteApplication
talkingPoint
validateAppNoFork
nativeValidate
