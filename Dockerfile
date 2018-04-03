# The docker image to generate Golang code from Protol Buffer.
FROM golang:1.9.2
MAINTAINER DL NGP-App-Infra-API <ngp-app-infra-api@infoblox.com>

WORKDIR /tmp

# Set up mandatory Go environmental variables.
ENV CGO_ENABLED=0

# Install zip tool to unpack the protoc compiler.
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && apt-get clean

# The version and the binaries checksum for the protocol buffers compiler.
ENV PROTOC_VERSION 3.0.0
ENV PROTOC_DOWNLOAD_URL https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip
ENV PROTOC_DOWNLOAD_SHA256 56e3f685ffe3c9516c5ed1da0aefd3f41010a051e8b36f1b538ac23298fccb30

# Download and install the protocol buffers compiler.
RUN curl -fsSL ${PROTOC_DOWNLOAD_URL} -o protoc.zip \
    && echo "${PROTOC_DOWNLOAD_SHA256} protoc.zip" | sha256sum -c - \
    && unzip -d /usr/local protoc.zip \
    && rm -rf protoc.zip

# The version and the binaries checksum for the glide package manager.
ENV GLIDE_VERSION 0.12.3
ENV GLIDE_DOWNLOAD_URL https://github.com/Masterminds/glide/releases/download/v${GLIDE_VERSION}/glide-v${GLIDE_VERSION}-linux-amd64.tar.gz
ENV GLIDE_DOWNLOAD_SHA256 0e2be5e863464610ebc420443ccfab15cdfdf1c4ab63b5eb25d1216900a75109

# Download and install the glide package manager.
RUN curl -fsSL ${GLIDE_DOWNLOAD_URL} -o glide.tar.gz \
    && echo "${GLIDE_DOWNLOAD_SHA256} glide.tar.gz" | sha256sum -c - \
    && tar -xzf glide.tar.gz --strip-components=1 -C /usr/local/bin \
    && rm -rf glide.tar.gz

# Install as the protoc plugins as build-time dependecies.
COPY glide.yaml .

# Compile binaries for the protocol buffer plugins. We need specific
# versions of these tools, this is why we at first step install glide,
# download required versions and then installing them.
RUN glide up --skip-test \
    && cp -r vendor/* ${GOPATH}/src/ \
    && go install github.com/golang/protobuf/protoc-gen-go \
    && go install github.com/gogo/protobuf/protoc-gen-combo \
    && go install github.com/gogo/protobuf/protoc-gen-gofast \
    && go install github.com/gogo/protobuf/protoc-gen-gogo \
    && go install github.com/gogo/protobuf/protoc-gen-gogofast \
    && go install github.com/gogo/protobuf/protoc-gen-gogofaster \
    && go install github.com/gogo/protobuf/protoc-gen-gogoslick \
    && go install github.com/gogo/protobuf/protoc-gen-gogotypes \
    && go install github.com/gogo/protobuf/protoc-gen-gostring \
    && go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger \
    && go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway \
    && go install github.com/lyft/protoc-gen-validate \
    && go install github.com/mwitkow/go-proto-validators/protoc-gen-govalidators \
    && go install github.com/pseudomuto/protoc-gen-doc/cmd/... \
    && go install github.com/infobloxopen/protoc-gen-gorm \
    && rm -rf vendor/* ${GOPATH}/pkg/*

WORKDIR ${GOPATH}/src

# protoc as an entry point for all plugins with import paths set
ENTRYPOINT ["protoc", "-I/usr/local/include", "-I.", \
    # required import paths for protoc-gen-grpc-gateway plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway/third_party/googleapis", \
    # required import paths for protoc-gen-swagger plugin
    "-Igithub.com/grpc-ecosystem/grpc-gateway", "-Igithub.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options", \
    # required import paths for extensions of protoc-gen-gogo
    "-Igithub.com/gogo/protobuf/protobuf", \
    # required import paths for protoc-gen-validate plugin
    "-Igithub.com/lyft/protoc-gen-validate/validate", \
    # required import paths for go-proto-validators plugin
    "-Igithub.com/mwitkow/go-proto-validators", \
    # googleapis proto files
    "-Igithub.com/googleapis/googleapis", \
    # required import paths for protoc-gen-gorm plugin
    "-Igithub.com/infobloxopen/protoc-gen-gorm" \
]
