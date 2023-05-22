A Docker compose project to stand up a Jupyter notebook server with [`nbstata`][nbs], so you can use Jupyter as a first-class UI for Stata.

[nbs]: https://github.com/hugetim/nbstata

`pystata`, on which `nbstata` depends, comes with Stata 17+. Older versions of Stata will not work.

# You need a Stata licence

The image expects you to supply it with a valid `stata.lic` file. Get this from your local install of Stata, or from your IT department.

Put a copy of it in the same directory as `docker-compose.yml`, or override the `file` key for the `stata_lic` secret to tell Docker where it is.

# Quickstart

```bash
$ docker compose up
```

Everything should Just Work. Caution: the build process will download several gigabytes of data, because Stata installs are big. As much of this is cached (using Docker cache-mounts) as possible.

If you are on an M1 Mac, the image will run under Rosetta, because there is no AArch64 build of Stata for Linux.

# Customisation, etc.

Rename [`docker-compose.override.sample.yml`][ov] to `docker-compose.override.yml` and anything you set in it will override the base config. (See [the Compose documentation][docs] for more information.)

[ov]: docker-compose.override.sample.yml
[docs]: https://docs.docker.com/compose/extends/#multiple-compose-files

The comments explain what you can override. In particular you will probably want to override `stata_edition` if your licence can accommodate it.

# Acknowledgements

- First inspired by David T. Jacho–Chávez's [“virtual econometrics lab”][vel]
- [kylebarron/stata_kernel][s_k] for the original, pre-`pystata` Stata kernel
  for JupyterLab that made this possible
- [ticoneva/pystata-kernel][psk] for building the new `pystata`-based kernel 
  and [hugetim/nbstata][nbs] for carrying it forward
- [AEADataEditor/docker-stata][aea] for the docker image that makes building 
  this vastly less painful than it was, and for the idea of mounting 
  `stata.lic` as a secret

[vel]: https://docs-jupyter.davidjachochavez.org/
[s_k]: https://github.com/kylebarron/stata_kernel/
[psk]: https://github.com/ticoneva/pystata-kernel/
[nbs]: https://github.com/hugetim/nbstata/
[aea]: https://github.com/AEADataEditor/docker-stata

