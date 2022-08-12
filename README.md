Dockerfile and miscellanea to bootstrap a [`stata_kernel`][1]-enabled Jupyter environment as a docker image, based on the official Jupyter docker images.

[1]: https://github.com/kylebarron/stata_kernel/

Heavily informed by https://docs-jupyter.davidjachochavez.org/.

## Installing

1. Clone this repo to somewhere under your control.
2. Download the Linux tarball from Stata's website using the credentials that came with your license file.
3. Install Stata locally and generate the `stata.lic` file.
4. Put both these files in `rsrc/`.
5. Run `docker build`.

You can specify an earlier version of Stata using, for example, `--build-arg stata_version=16`. 

Note that if you are using Stata 17 there is a [bug in `stata_kernel`][2] which affects the display of Stata graphs.

[2]: https://github.com/kylebarron/stata_kernel/issues/428
