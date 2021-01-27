FROM python:3.9.1-slim-buster@sha256:b2013807b8af03d66f60a979f20d4e93e4e4a111df1287d9632c8cfd41ecfa33

LABEL maintainer "Paul Sud"
LABEL maintainer.email "encode-help@lists.stanford.edu"

RUN mkdir -p /usr/share/man/man1

RUN apt update && \
    apt install -y default-jre && \
    rm -rf /var/lib/apt/lists/*

ADD https://github.com/jernst98/ChromHMM/raw/515c2bf3cbdf66539228bb4dd6aba555f97675b6/ChromHMM.jar /opt/ChromHMM.jar
RUN chmod a+rw /opt/ChromHMM.jar

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && rm requirements.txt

COPY chromhmm_pipeline /opt/chromhmm_pipeline
ENV PATH="/opt/chromhmm_pipeline/:${PATH}"
