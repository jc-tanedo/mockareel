The Tokyo Station scene contains simplified PLATEAU building footprints and heights (MLIT Japan), street and ground geometry, and GSI elevation samples. Its origin is 35.68124 N, 139.76712 E. Geometry is rounded to metres and the elevation grid is sampled every 50 metres. Credits are displayed in the map shot.

The source compilation includes OpenStreetMap contributions. This derived database, tokyo.json, is made available under the [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/). [Source compiled tiles](https://github.com/jeantimex/tokyo/tree/ba88f5f9dbc6782a729692c3743e70b27ba78498/tiles/tokyo) · [Project PLATEAU](https://www.mlit.go.jp/plateau/) · [GSI](https://www.gsi.go.jp/) · [OSM copyright](https://www.openstreetmap.org/copyright).

Other locations use OpenStreetMap contributors’ building and land-use data under ODbL and Mapzen Terrarium elevation tiles where available. Building heights are estimated from storeys when explicit heights are missing. [Elevation credits](https://github.com/tilezen/joerd/blob/master/docs/attribution.md).

For new captures the app combines footprints around the pin, in this order:

- In Japan, Project PLATEAU (MLIT), processed by Pacific Spatial Solutions (FLatEAU) and distributed by shiwaku. The 2023 LOD0 archive covers 211 municipalities. The app converts footprints to local metres and extrudes them using available height attributes. [Archive and CC BY 4.0 license](https://github.com/shiwaku/mlit-plateau-bldg-pmtiles)
- In metropolitan France including Corsica, IGN BD TOPO building polygons and heights, licensed under Licence Ouverte 2.0. [BD TOPO](https://geoservices.ign.fr/bdtopo)
- Worldwide, OpenStreetMap via Overpass and Overture Maps Foundation's buildings theme. Overture incorporates multiple footprint datasets including Microsoft and Google Open Buildings. The app reads local tiles from the current public release, keeping source credits from retained features. Builds can point to a compatible hosted archive with `--dart-define=OVERTURE_BUILDINGS_PMTILES=https://…`. [Overture buildings](https://docs.overturemaps.org/guides/buildings/) · [Attribution and licensing](https://docs.overturemaps.org/attribution/) · [OSM copyright](https://www.openstreetmap.org/copyright)
- Where few buildings load, OpenFreeMap's OpenMapTiles building layer provides a second distribution of OSM footprints. [OpenFreeMap credits](https://openfreemap.org/)
- In Japan, terrain uses the GSI 5 m DEM where available, then the general GSI DEM. Other locations and gaps use Mapzen Terrarium. The scene samples the chosen source on a 50 m grid. [GSI elevation tiles](https://maps.gsi.go.jp/development/ichiran.html)

When building heights are missing, the scene uses 3 m per reported storey or a 9 m default. Individual feeds can be unavailable or lack coverage. Re-capturing a saved location applies the current source selection.
