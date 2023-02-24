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
  pei "java -version"
  pei "curl https://start.spring.io/starter.tgz -d dependencies=web,actuator -d javaVersion=17 -d bootVersion=2.7.9 -d type=maven-project | tar -xzf - || exit"
  pei "git init"
  pei "git add ."
  pei 'git commit -m "Initializr"'
}

function validateApp {
  pei "./mvnw -q clean package spring-boot:start -DskipTests"
  pei "http :8080/actuator/health"
  pei "vmmap $(jps | grep DemoApplication | cut -d ' ' -f 1) | grep Physical"
  pei "./mvnw spring-boot:stop -Dspring-boot.stop.fork"
}

function rewriteApplication {
  pei "./mvnw -q -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST -DactiveRecipes=org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0"
  pei "./mvnw -q -U org.openrewrite.maven:rewrite-maven-plugin:run -Drewrite.recipeArtifactCoordinates=org.openrewrite:rewrite-maven:LATEST -DactiveRecipes=org.openrewrite.maven.RemoveDuplicateDependencies"
}

function nativeValidate {
  pei "./mvnw -Pnative native:compile -DskipTests"
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
validateApp
nativeValidate