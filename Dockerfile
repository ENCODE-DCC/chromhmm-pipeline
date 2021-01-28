FROM python:3.9.1-slim-buster@sha256:b2013807b8af03d66f60a979f20d4e93e4e4a111df1287d9632c8cfd41ecfa33

LABEL maintainer "Paul Sud"
LABEL maintainer.email "encode-help@lists.stanford.edu"

RUN mkdir -p /usr/share/man/man1

RUN apt update && \
    apt install -y default-jre git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone https://github.com/jernst98/ChromHMM.git && \
    cd ChromHMM && \
    chmod a+rw ChromHMM.jar && \
    rm -rf ChromHMM.zip CHROMSIZES SAMPLEDATA_HG18 edu/mit/compbio/ChromHMM ChromHMM_manual.pdf README.md

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && rm requirements.txt

COPY chromhmm_pipeline /opt/chromhmm_pipeline
ENV PATH="/opt/chromhmm_pipeline/:${PATH}"
