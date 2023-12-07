ARG UBUNTU_RELEASE=22.04

# first, build the "chisel" image with ../Dockerfile
# docker build .. --build-arg UBUNTU_RELEASE=22.04 -t chisel:22.04

FROM chisel:${UBUNTU_RELEASE} as installer
WORKDIR /staging
RUN [ "chisel", "cut", "--release", "ubuntu-22.04", \
    "--root", "/staging/", "libc6_libs", "libstdc++6_libs" ]

FROM public.ecr.aws/lts/ubuntu:${UBUNTU_RELEASE} AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y ca-certificates curl gnupg
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR=20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update
RUN apt-get install -y nodejs
RUN npm install -g yarn
COPY app.js package.json yarn.lock ./
RUN yarn install

FROM scratch
COPY --from=installer [ "/staging/", "/" ]
COPY --from=builder /usr/bin/node /usr/bin/
WORKDIR /app
COPY --from=builder /app .
EXPOSE 3000
CMD [ "node", "app.js" ]

# docker run --rm -it $(docker build . -q -f helloworld.dockerfile)