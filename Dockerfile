ARG UBUNTU_RELEASE=22.04

FROM public.ecr.aws/ubuntu/ubuntu:${UBUNTU_RELEASE}_stable AS installer
ARG NODE_VERSION
RUN groupadd --system --gid 1001 nodejs && adduser --system --uid 1001 nx

# Install apt dependencies
RUN apt-get update && apt-get install -y python3 make g++ curl gnupg2 ca-certificates xz-utils && apt-get clean 

# Node install layer
RUN curl -s -L https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz | tar xJf - -C /usr --strip-components=1 && \
    npm install -g yarn node-gyp && \
    npm cache clean --force

# Current release v0.9.1 March 14, 2024 includes breaking change to canonical/chisel-releases
RUN curl -sSfL https://github.com/canonical/chisel/releases/download/v0.9.1/chisel_v0.9.1_linux_amd64.tar.gz | tar xz -C /usr/bin/ chisel    


FROM installer AS builder
WORKDIR /staging
RUN [ "chisel", "cut", "--release", "ubuntu-22.04", \
    "--root", "/staging/", \
    "bash_bins", \
    "libstdc++6_libs" ]    

WORKDIR /src
# Copy package.json, yarn lockfile, and .npmrc with Github token to /src
COPY package.json yarn.lock ./
# Install node modules, cleanup yarn cache, remove package.json, yarn.lock, and .npmrc
RUN yarn --prod --frozen-lockfile && yarn cache clean

FROM scratch
COPY --from=builder /staging/ /
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /usr/bin/node /usr/bin/node
WORKDIR /src
COPY --from=builder /src .
COPY app.js .
EXPOSE 3000
CMD ["node", "app.js"]
