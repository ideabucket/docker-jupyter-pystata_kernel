#syntax=docker/dockerfile:1

ARG base_image="jupyter/minimal-notebook"
ARG stata_version=17
ARG stata_update_tarball="https://www.stata.com/support/updates/stata${stata_version}/stata${stata_version}update_linux64.tar"
ARG stata_target_dir=/usr/local/stata${stata_version}

ARG kernel_pkgname=nbstata
ARG conda_nbstatadeps="bqplot fastcore gast ipydatagrid ipywidgets jupyterlab_widgets numpy pandas py2vega traittypes tzdata widgetsnbextension"
ARG conda_packagelist="jupyterlab-git nodejs"

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
COPY --from=dataeditors/stata17:2023-03-08 /usr/local/stata /usr/local/stata

# whoops, who left that there
RUN if [ -f /usr/local/stata.lic.bak ]; then rm /usr/local/stata/stata.lic.bak; fi

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
# we have to manually remove some directories, because stata's update
# process tries to delete them using a process that doesn't work 
# inside docker images (weird, right?)
RUN --mount=type=secret,id=stata_lic,target=/usr/local/stata/stata.lic,required=true \
	rm -rf /usr/local/stata/utilities/jar && \
	rm -rf /usr/local/stata/utilities/java && \
	rm -rf /usr/local/stata/utilities/pystata && \
	/usr/local/stata/stata -q \
		-b 'update all, force from("/tmp/stata_update")' && \
	/bin/bash -c "cd /usr/local/stata && ./setrwxp now"




# Step 2: build the final image

FROM --platform=amd64 ${base_image}:latest

ARG stata_version
ARG stata_update_tarball
ARG stata_target_dir
ARG kernel_pkgname
ARG conda_packagelist
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

RUN mamba install -c conda-forge -y ${conda_nbstatadeps} ${conda_packagelist} && \
	pip install ${kernel_pkgname} jupyterlab_stata_highlight2 && \
	python -m ${kernel_pkgname}.install	

# populate pystata-kernel.conf
COPY --chown=${NB_UID}:${NB_GID} <<-EOF /home/${NB_USER}/.nbstata.conf
	[nbstata]
	stata_dir = ${stata_target_dir}
	edition = ${stata_edition}
	graph_format = ${graph_format}
	echo = ${echo_behavior}
	splash = ${splash_behavior}
	missing = NA
EOF
