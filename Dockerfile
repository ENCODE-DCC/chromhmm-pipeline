FROM ubuntu:18.04

LABEL maintainer "Keshav Gurushankar"
LABEL maintainer.email "encode-help@lists.stanford.edu"

RUN apt update && \
	apt install -y default-jre git

RUN git clone https://github.com/jernst98/ChromHMM.git