#syntax=docker/dockerfile:1

# we copy the stata binaries from the officially sanctioned stata17 
# image provided by the AEA Data Editor
# because the AEA images are focused on reproducibility, they by design 
# do not have a :latest tag so we have to be specific
FROM dataeditors/stata17:2022-07-19 AS aea-stata

# substitute jupyter/r-notebook:latest if you want an R kernel as well
FROM jupyter/minimal-notebook:latest

ARG stata_version=17

ARG stata_update_tarball="https://www.stata.com/support/updates/stata${stata_version}/stata${stata_version}update_linux64.tar"
ARG stata_target_dir=/usr/local/stata${stata_version}

# to build image with the dev kernel instead, override this arg with
# git+https://github.com/ticoneva/pystata-kernel.git
ARG kernel_pkgname=pystata-kernel

# these args populate the pystata-kernel config file
ARG stata_edition=be
ARG graph_format=pystata
ARG echo_behavior=False
ARG splash_behavior=False

EXPOSE 8888/tcp

USER root 

COPY --from=aea-stata /usr/local/stata ${stata_target_dir}

RUN	--mount=type=secret,id=stata_lic,target=${stata_target_dir}/stata.lic,required=true \
	ln -s ${stata_target_dir} /usr/local/stata && \
	apt-get update && \
	apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
	apt-get -y upgrade && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	mkdir -m 775 /tmp/stata_update && \
	wget --output-document=/tmp/stata_update.tar \
			--no-verbose -- ${stata_update_tarball} && \
	tar --extract --no-same-owner --directory=/tmp/stata_update \
			--strip-components=1 \
			--file=/tmp/stata_update.tar && \
	rm -rf ${stata_target_dir}/utilities/jar && \
	rm -rf ${stata_target_dir}/utilities/java && \
	rm -rf ${stata_target_dir}/utilities/pystata && \
	${stata_target_dir}/stata -q \
		-b 'update all, force from("/tmp/stata_update")' && \
	/bin/bash -c "cd ${stata_target_dir} && ./setrwxp now" && \
	rm -rf /tmp/stata_update.tar && \
	rm -rf /tmp/stata_update


# NB_UID arg is inherited from the official Jupyter dockerfiles
USER ${NB_UID}

ENV PATH=${stata_target_dir}:$PATH
ENV JUPYTER_ENABLE_LAB=yes

RUN pip install ${kernel_pkgname} && \
	python -m pystata-kernel.install && \
	conda install -c conda-forge jupyterlab-git nodejs -y && \
	jupyter labextension install jupyterlab-stata-highlight

# heredocs depend on syntax v1.4+
COPY <<-EOF /home/${NB_USER}/.pystata-kernel.conf
	[pystata-kernel]
	stata_dir = ${stata_target_dir}
	edition = ${stata_edition}
	graph_format = ${graph_format}
	echo = ${echo_behavior}
	splash = ${splash_behavior}
EOF
