#syntax=docker/dockerfile:1

ARG stata_version=17
ARG stata_tarball=rsrc/Stata${stata_version}Linux64.tar.gz
ARG license_file=rsrc/stata.lic

ARG stata_install_dir=/tmp/stata_install

# to build image with the dev kernel instead, override this arg with
# git+https://github.com/ticoneva/pystata-kernel.git
ARG kernel_pkgname=pystata-kernel

ARG stata_target_dir=/usr/local/stata${stata_version}

# this path has changed between versions before and might do so again
ARG taz_path=${stata_install_dir}/unix/linux64

# these args populate the config file
ARG stata_edition=be
ARG graph_format=pystata
ARG echo_behavior=None

# also compatible with r-notebook
FROM jupyter/minimal-notebook:latest

EXPOSE 8888/tcp

USER root 

ADD ${stata_tarball} ${stata_install_dir}

RUN mkdir -m 775 ${stata_target_dir} && \
	ln -s ${stata_target_dir} /usr/local/stata && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/base.taz && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/bins.taz && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/ado.taz && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/docs.taz && \
	/bin/bash -c \
	"cd ${stata_target_dir} && ${taz_path}/setrwxp now" && \
    rm -rf ${stata_install_dir} 
	
COPY ${license_file} ${stata_target_dir}

RUN	apt-get update && \
    apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
    apt-get -y upgrade && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# NB_UID arg is inherited from the official Jupyter dockerfiles
USER ${NB_UID}

ENV PATH=${stata_target_dir}:$PATH
ENV JUPYTER_ENABLE_LAB=yes

RUN pip install ${kernel_pkgname} && \
    python -m pystata-kernel.install && \
	conda install -c conda-forge nodejs -y && \
	jupyter labextension install jupyterlab-stata-highlight && \
	jupyter labextension install git

# heredocs depend on syntax v1.4+
COPY <<-EOF /home/${NB_USER}/.pystata-kernel.conf
	[pystata-kernel]
	stata_dir = ${stata_target_dir}
	edition = ${stata_edition}
	graph_format = ${graph_format}
	echo = ${echo_behavior}
EOF