FROM ubuntu:18.04

LABEL maintainer "Keshav Gurushankar"
LABEL maintainer.email "encode-help@lists.stanford.edu"

# doing this up here to not deal with interactive junk below
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt install -y tzdata && \
	apt install -y nodejs npm default-jre awscli git

COPY node/* node/
RUN cd node && npm i && cd ..
ENV PATH="/node:${PATH}"

RUN git clone https://github.com/jernst98/ChromHMM.git
ENV PATH="/ChromHMM:${PATH}"

# Where do I setup aws credentials file? or does caper handle that