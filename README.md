Dockerfile and miscellanea to bootstrap a Jupyter notebook environment using [`pystata-kernel`][1]. Works with Stata 17. Doesn't work with previous versions since they didn't ship with `pystata`.

[1]: https://github.com/ticoneva/pystata-kernel

# Before you start

You need a valid `stata.lic` file to build the image, and to run the container. Assuming you have a legitimate Stata license, the easiest way to obtain the `.lic` file is to install Stata on your local machine---the license file is platform-independent.

# Building the image

You _must_ pass your `stata.lic` file to `docker build` as a secret named `stata_lic`. The parameter for this is:

```bash
docker build --secret id=stata_lic,src=/path/to/stata.lic …
```

In addition you can override the following build-args:

## `pystata-kernel` config file options

These are used to populate `.pystata-kernel.conf`. See the [`pystata-kernel` documentation][psk-conf] for what they do.

- `stata_edition`: Corresponds to `edition` config directive. Defaults to `be`, which will work with all licenses. If you have a better license, you probably want to override this one.
- `graph_format`: Defaults to `pystata`.
- `echo_behavior`: Corresponds to `echo` config directive.
- `splash_behavior`: Corresponds to `splash` config directive.

[psk-conf]: https://github.com/ticoneva/pystata-kernel#configuration

## Build-time options

- `kernel_pkgname`: Defaults to `pystata-kernel`, so `pip` will install the release version. But can be overriden to, e.g., `git+https://github.com/ticoneva/pystata-kernel.git` to install the latest dev version. Absolutely no sanity-checking is done on this, but overriding it to something other than a version of pystata-kernel will likely have hilariously stupid results.
- `stata_target_dir`: Where to put the Stata binaries in the image. Defaults to `/usr/local/stata${stata_version}`. Whatever you specify will be symlinked to `/usr/local/stata`.
- `stata_update_tarball`: URL of the _update_ tarball to be passed to stata's `update all` command. Preset to the download link for Linux on  https://www.stata.com/support/updates/ as of this commit.
- `stata_version`: Self-explanatory. Defaults to 17.

# Running the container

When you run the container, make sure you mount your `stata.lic` at `/usr/local/stata/stata.lic`. The image installs `jupyterlab-git`; if you want to use this to push to GitHub, mount a directory with an ssh key in it at `/home/jovyan/.ssh`.

# Acknowledgements

- First inspired by David T. Jacho–Chávez's [“virtual econometrics lab”][vel]
- [kylebarron/stata_kernel][s_k] for the original, pre-`pystata` Stata kernel for JupyterLab that made this possible
- [ticoneva/pystata-kernel][psk] for building the new `pystata`-based kernel
- [AEADataEditor/docker-stata][aea] for the docker image that makes building this vastly less painful than it was, and for the idea of mounting `stata.lic` as a secret

[vel]: https://docs-jupyter.davidjachochavez.org/
[s_k]: https://github.com/kylebarron/stata_kernel/
[psk]: https://github.com/ticoneva/pystata-kernel/
[aea]: https://github.com/AEADataEditor/docker-stata
