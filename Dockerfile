FROM ubuntu:bionic as build

ARG REQUIRED_PACKAGES="vim"

ENV ROOTFS /build/rootfs
ENV BUILD_DEBS /build/debs
ENV DEBIAN_FRONTEND=noninteractive

# Build pre-requisites
RUN bash -c 'mkdir -p ${BUILD_DEBS} ${ROOTFS}/{sbin,usr/bin,usr/local/bin}'

# Fix permissions
RUN chown -Rv 100:root $BUILD_DEBS

# Unpack required packges to rootfs
RUN apt-get update \
  && cd ${BUILD_DEBS} \
  && for pkg in $REQUIRED_PACKAGES; do \
       apt-get download $pkg \
         && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends -i $pkg | grep '^[a-zA-Z0-9]' | xargs apt-get download ; \
     done
RUN if [ "x$(ls ${BUILD_DEBS}/)" = "x" ]; then \
      echo No required packages specified; \
    else \
      for pkg in ${BUILD_DEBS}/*.deb; do \
        echo Unpacking $pkg; \
        dpkg -x $pkg ${ROOTFS}; \
      done; \
    fi

# Move /sbin out of the way
RUN mv ${ROOTFS}/sbin ${ROOTFS}/sbin.orig \
      && mkdir -p ${ROOTFS}/sbin \
      && for b in ${ROOTFS}/sbin.orig/*; do \
           echo 'cmd=$(basename ${BASH_SOURCE[0]}); exec /sbin.orig/$cmd "$@"' > ${ROOTFS}/sbin/$(basename $b); \
           chmod +x ${ROOTFS}/sbin/$(basename $b); \
         done

# /usr/bin/vim => /usr/bin/vim.basic symlink
RUN ln -s vim.basic ${ROOTFS}/usr/bin/vim

COPY entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/bash:4.4.18-6
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS=/build/rootfs

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]