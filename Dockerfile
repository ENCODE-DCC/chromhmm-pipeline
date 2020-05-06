FROM ubuntu:18.04

LABEL maintainer "Keshav Gurushankar"
LABEL maintainer.email "encode-help@lists.stanford.edu"

# doing this up here to not deal with interactive junk below
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt install -y tzdata && \
	apt install -y nodejs npm default-jre git
COPY node/* node/
RUN cd node && npm i && cd ..
RUN git clone https://github.com/jernst98/ChromHMM.git

# Where do I setup aws credentials file? or does caper handle that