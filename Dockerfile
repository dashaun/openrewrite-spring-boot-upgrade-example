FROM debian:bookworm

# install dependencies
RUN apt-get update &&\
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y bc ca-certificates curl gcc git gpg procps pv unzip wget zip zlib1g-dev &&\
  rm -rf /var/lib/apt/lists/*

# install demo magic
RUN curl --output /usr/local/bin/demo-magic.sh "https://raw.githubusercontent.com/paxtonhare/demo-magic/master/demo-magic.sh" &&\
  chmod +x /usr/local/bin/demo-magic.sh

# install sdkman
RUN curl -s "https://get.sdkman.io" | bash

# install httpie
RUN curl -SsL https://packages.httpie.io/deb/KEY.gpg | gpg --dearmor -o /etc/apt/keyrings/httpie.gpg &&\
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/httpie.gpg] https://packages.httpie.io/deb ./" > /etc/apt/sources.list.d/httpie.list &&\
  apt-get update &&\
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y httpie &&\
  rm -rf /var/lib/apt/lists/*

# configure git
RUN git config --global user.email "demo@example.com" &&\
  git config --global user.name "demo user" &&\
  git config --global init.defaultBranch master

# install carvel tools (vendir)
RUN curl -L https://carvel.dev/install.sh | bash
