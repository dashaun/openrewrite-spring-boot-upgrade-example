#!/usr/bin/env bash
. demo-magic.sh
export TYPE_SPEED=100
export DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
TEMP_DIR=upgrade-example

function talkingPoint() {
  p ""
  wait
  clear
}

function initSDKman() {
  source "$HOME/.sdkman/bin/sdkman-init.sh"
}

function createAppWithInitializr {
  # hide the evidence
  rm -rf $TEMP_DIR
  mkdir $TEMP_DIR
  cd $TEMP_DIR || exit
  clear
  pei "sdk use java 8.0.372-librca"
  pei "java -version"
  pei "curl https://start.spring.io/starter.tgz -d dependencies=web,actuator -d javaVersion=8 -d bootVersion=2.7.1 -d type=maven-project | tar -xzf - || exit"
  pei "git init && git add . && git commit -m 'initializr'"
}

function validateApp {
  pei "./mvnw -q clean package spring-boot:start -DskipTests"
  pei "http :8080/actuator/health"
  pei "vmmap $(jps | grep DemoApplication | cut -d ' ' -f 1) | grep Physical"
  pei "./mvnw spring-boot:stop -Dspring-boot.stop.fork"
}

function rewriteApplication {
  pei "./mvnw -q -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST -DactiveRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0"
#  pei "./mvnw -q -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite:rewrite-maven:LATEST -DactiveRecipes=org.openrewrite.maven.RemoveDuplicateDependencies"
  pei "sdk use java 22.3.1.r17-grl"
  pei "java -version"
}

function nativeValidate {
  pei "./mvnw -Pnative native:compile -DskipTests"
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
validateApp
rewriteApplication
nativeValidate