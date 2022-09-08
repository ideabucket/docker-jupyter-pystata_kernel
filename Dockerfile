#syntax=docker/dockerfile:1

ARG stata_version=17
ARG stata_update_tarball="https://www.stata.com/support/updates/stata${stata_version}/stata${stata_version}update_linux64.tar"
ARG stata_target_dir=/usr/local/stata${stata_version}

ARG kernel_pkgname=pystata-kernel

# these args populate the pystata-kernel config file
ARG stata_edition=be
ARG graph_format=pystata
ARG echo_behavior=False
ARG splash_behavior=False

# Step 1: use an intermediate image to fetch the stata binaries and make
# sure they are up to date for a smaller final image
# see: https://docs.docker.com/develop/develop-images/multistage-build/
#
# we use ubuntu rather than alpine as the base image because stata 
# demands ncurses 5, which is legacy and not available as an apk
FROM --platform=amd64 ubuntu:latest AS intermediate

ARG stata_version
ARG stata_update_tarball

# obtain the base stata install from the AEA Data Editor's officially 
# sanctioned dockerized Stata image--it by design does not have a ':latest'
# tag (because it's about reproducibility) so we have to be specific
COPY --from=dataeditors/stata17:2022-07-19 /usr/local/stata /usr/local/stata

# whoops, who left that there
RUN rm /usr/local/stata/stata.lic.bak

RUN apt-get update && \
	apt-get install -y wget && \
	apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
	apt-get -y upgrade && \
	apt-get clean 
	
# fetch the stata update tarball (this is more robust than letting stata do it)
RUN --mount=type=cache,target=/tmp/stata_cache \
	wget --directory-prefix=/tmp/stata_cache --timestamping \
			--no-verbose -- ${stata_update_tarball}
			
RUN --mount=type=cache,target=/tmp/stata_cache \
	mkdir -m 775 /tmp/stata_update && \
	tar --extract --no-same-owner --directory=/tmp/stata_update \
			--strip-components=1 \
			--file=/tmp/stata_cache/stata${stata_version}update_linux64.tar

# tell stata to update itself from the tarball we just fetched
RUN --mount=type=secret,id=stata_lic,target=/usr/local/stata/stata.lic,required=true \
	rm -rf /usr/local/stata/utilities/jar && \
	rm -rf /usr/local/stata/utilities/java && \
	rm -rf /usr/local/stata/utilities/pystata && \
	/usr/local/stata/stata -q \
		-b 'update all, force from("/tmp/stata_update")' && \
	/bin/bash -c "cd /usr/local/stata && ./setrwxp now"




# Step 2: build the final image

FROM jupyter/minimal-notebook:latest

ARG stata_version
ARG stata_update_tarball
ARG stata_target_dir
ARG kernel_pkgname
ARG stata_edition
ARG graph_format
ARG echo_behavior
ARG splash_behavior

EXPOSE 8888/tcp

USER root 

# let the NB_USER own the stata directory so stata can be updated from
# inside the container if necessary
COPY --from=intermediate --chown=${NB_UID}:${NB_GID} /usr/local/stata ${stata_target_dir}

RUN ln -s ${stata_target_dir} /usr/local/stata && \
	apt-get update && \
	apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
	apt-get -y upgrade && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

USER ${NB_USER}

ENV PATH=${stata_target_dir}:$PATH
ENV JUPYTER_ENABLE_LAB=yes

RUN pip install ${kernel_pkgname} && \
	python -m pystata-kernel.install && \
	conda install -c conda-forge jupyterlab-git jupyterlab-mathjax3 nodejs -y && \
	jupyter labextension install jupyterlab-stata-highlight

# populate pystata-kernel.conf
COPY --chown=${NB_UID}:${NB_GID} <<-EOF /home/${NB_USER}/.pystata-kernel.conf
	[pystata-kernel]
	stata_dir = ${stata_target_dir}
	edition = ${stata_edition}
	graph_format = ${graph_format}
	echo = ${echo_behavior}
	splash = ${splash_behavior}
EOF
