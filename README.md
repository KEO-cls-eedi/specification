# KEO CLS.EEDI Experimental

This is the documentation of CLS.EEDI. It allows backend systems to exchange grid and energy management related data with
local systems at the grid connection point (GCP). CLS.EEDI is a convenient implementation of the use cases standardized
in VDE-AR 2829-6.

Note that this is an experimental version of the CLS.EEDI specification. All statements made in this document, in
the schema files, and in the examples can change at any time. Follow
[this link](https://github.com/KEO-cls-eedi/specification) to find the most recent stable version.

# Collaboration Guidelines

Requests for collaboration will be welcomed. We are very interested to get input from all involved parties and commit to
moderate discussions on CLS.EEDI within the community. The safest mode of collaboration in this repository is to start a
discussion first. For this, either open an issue here on GitHub or write an email to cls.eedi@keo-connectivity.de.

If you open a pull request on GitHub make sure to update all related files. For most changes you will need to update
the descriptions in [docs/clseedi.md](https://github.com/KEO-cls-eedi/specification/blob/main/doc/clseedi.md), update
the JSON schema files in [schemas/](https://github.com/KEO-cls-eedi/specification/tree/main/schemas) and
[schemas/clseedi/](https://github.com/KEO-cls-eedi/specification/tree/main/schemas/clseedi/), and update the example
JSONs in [schemas/clseedi/examples/](https://github.com/KEO-cls-eedi/specification/tree/main/schemas/clseedi/examples).

# Building

To render the documentation check and use `build.sh`. Dependencies for building are `doxygen` and `plantuml`.

# Further reading
* https://www.keo-connectivity.de/
* https://www.eebus.org/

# License

This documentation defines the KEO CLS.EEDI protocol.

Copyright (C) 2022 KEO GmbH

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; version 2
of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
