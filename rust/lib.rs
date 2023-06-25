use geom::*;
use rustc_hash::FxHashMap as HashMap;
use wasm_bindgen::prelude::*;
use web_sys::console;

// When the `wee_alloc` feature is enabled, use `wee_alloc` as the global
// allocator.
#[cfg(feature = "wee_alloc")]
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

#[wasm_bindgen]
extern "C" {
    fn alert(s: &str);
}

#[wasm_bindgen]
pub fn greet() {
    alert("Hello!");
}

const TILE_SIZE: f64 = 200.;

#[wasm_bindgen]
pub fn tile_extents(tile_idx: u32, extents: &Extents3) -> Option<Extents3> {
    let [dx, dy] = extent_dims(extents);
    let extents = Extents2::from(*extents);

    if tile_idx >= dx * dy {
        None
    } else {
        let origin = [tile_idx % dx, tile_idx / dx]
            .map(|x| x as f64)
            .scale(TILE_SIZE)
            .add(extents.origin);
        Some(
            Extents2 {
                origin,
                size: Point2::all(TILE_SIZE),
            }
            .into(),
        )
    }
}

#[inline(always)]
fn extent_dims(extents: &Extents3) -> [u32; 2] {
    Extents2::from(*extents)
        .size
        .map(|x| (x / TILE_SIZE).ceil() as u32)
}

trait Store {
    fn to_bytes(&self) -> Vec<u8>;
    fn from_bytes(bytes: &[u8]) -> Result<Self, String>
    where
        Self: Sized;
}

macro_rules! wasm_bindgen_store_impl {
    ($t:ty) => {
        #[wasm_bindgen]
        impl $t {
            pub fn to_bytes(&self) -> Vec<u8> {
                Store::to_bytes(self)
            }
            pub fn from_bytes(bytes: &[u8]) -> Result<$t, String> {
                Store::from_bytes(bytes)
            }
        }
    };
}

#[wasm_bindgen(inspectable)]
#[derive(Copy, Clone, Debug)]
pub struct Point3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Point3 {
    pub fn zero() -> Self {
        geom::Point3::zero().into()
    }
}

impl From<geom::Point3> for Point3 {
    fn from([x, y, z]: geom::Point3) -> Self {
        Self { x, y, z }
    }
}
impl From<Point3> for geom::Point3 {
    fn from(value: Point3) -> Self {
        let Point3 { x, y, z } = value;
        [x, y, z]
    }
}
impl From<Point3> for geom::Point2 {
    fn from(value: Point3) -> Self {
        let Point3 { x, y, z } = value;
        [x, y]
    }
}

#[wasm_bindgen(inspectable)]
#[derive(Copy, Clone, Debug)]
pub struct Extents3 {
    pub origin: Point3,
    pub size: Point3,
}

#[wasm_bindgen]
impl Extents3 {
    /// Returns the maximum size dimension.
    ///
    /// This is useful as the scaler value for working in _render_ space.
    pub fn max_dim(&self) -> f64 {
        let Point3 { x, y, z } = self.size;
        x.max(y).max(z)
    }

    /// A default extents going from zero to one in all dimensions.
    pub fn zero_to_one() -> Self {
        Self {
            origin: Point3::zero(),
            size: geom::Point3::one().into(),
        }
    }

    /// Transforms a _render_ coordinate into a _world_ coordinate by reversing the transform.
    ///
    /// Note that _x,y,z_ is in Y-up, such that y/z are swapped, but the returned world coordinate
    /// is in Z-up (so y/z will be swapped.)
    ///
    /// We assume that the render coordinate was initially calculated by using the extents
    /// (since this bounds the transformation).
    pub fn render_to_world(&self, x: f64, y: f64, z: f64) -> Point3 {
        let scaler = self.max_dim();
        geom::Point3::from(self.origin)
            // note the swap to Z-up
            .add([x, z, y].scale(scaler))
            .into()
    }

    /// Creates an extents with the origin at _x,y,z_ and size 0.
    pub fn from_pt(x: f64, y: f64, z: f64) -> Self {
        Self {
            origin: [x, y, z].into(),
            size: Point3::zero(),
        }
    }

    /// Expand the extents to include this point.
    pub fn expand(&mut self, x: f64, y: f64, z: f64) {
        use geom::Extents3 as E3;

        let this = E3::from(*self);
        let min = this.origin.min_all([x, y, z]);
        let max = this.max().max_all([x, y, z]);
        *self = E3::from_min_max(min, max).into();
    }
}

impl From<Extents3> for geom::Extents3 {
    fn from(value: Extents3) -> Self {
        geom::Extents3 {
            origin: value.origin.into(),
            size: value.size.into(),
        }
    }
}
impl From<geom::Extents3> for Extents3 {
    fn from(value: geom::Extents3) -> Self {
        let geom::Extents3 { origin, size } = value;
        Extents3 {
            origin: origin.into(),
            size: size.into(),
        }
    }
}
impl From<Extents3> for geom::Extents2 {
    fn from(value: Extents3) -> Self {
        Extents2 {
            origin: value.origin.into(),
            size: value.size.into(),
        }
    }
}
impl From<geom::Extents2> for Extents3 {
    fn from(value: geom::Extents2) -> Self {
        Self {
            origin: value.origin.with_z(0.).into(),
            size: value.size.with_z(0.).into(),
        }
    }
}

wasm_bindgen_store_impl!(Extents3);
impl Store for Extents3 {
    /// Deserialize binary data to get [`Extents3`].
    ///
    /// # Format
    /// The format is simple a list of 6 64-bit floats (48 bytes).
    /// The first three represent the origin, the next three represent the size.
    /// **Encoding is in Big Endian.**
    fn from_bytes(bytes: &[u8]) -> Result<Self, String>
    where
        Self: Sized,
    {
        let mut d = StoreDecoder::new(bytes);

        Ok(Self {
            origin: Point3 {
                x: d.f64()?,
                y: d.f64()?,
                z: d.f64()?,
            },
            size: Point3 {
                x: d.f64()?,
                y: d.f64()?,
                z: d.f64()?,
            },
        })
    }

    fn to_bytes(&self) -> Vec<u8> {
        let Self { origin, size } = self;

        let mut v = Vec::with_capacity(6 * 8);
        v.extend(origin.x.to_be_bytes());
        v.extend(origin.y.to_be_bytes());
        v.extend(origin.z.to_be_bytes());
        v.extend(size.x.to_be_bytes());
        v.extend(size.y.to_be_bytes());
        v.extend(size.z.to_be_bytes());

        v
    }
}

/// A _surface_ spatial object consisting of a bunch of triangles.
///
/// This object is meant to be fed into the `Viewer` object.
/// Since it will usually be transferred across the network, it is optimised for space.
/// It consists of an array of 'points' (x,y,z coordinates as 32-bit floats), an array of 'faces'
/// (32-bit indices of p1,p2,p3), and a translation `Point3`.
///
/// The points are 32-bit to save on space. The translation point is recommended to be the lower
/// AABB point. Each point will be translated like so:
/// `translate` + `(x,y,z)`
#[wasm_bindgen]
pub struct TriangleMeshSurface {
    points: Vec<f32>,
    indices: Vec<u32>,
    pub translate: Point3,
}

#[wasm_bindgen]
impl TriangleMeshSurface {
    /// Calculate the AABB of the mesh.
    ///
    /// Note that this returns in _real_ space, not translated space.
    pub fn aabb(&self) -> Extents3 {
        let o = geom::Point3::from(self.translate);

        self.points
            .chunks_exact(3)
            .map(|p| {
                let p: [f32; 3] = p.try_into().expect("size 3");
                p.map(|x| x as f64).add(o)
            })
            .collect::<geom::Extents3>()
            .into()
    }

    /// Fills `self` by deserializing a vulcan 00t triangulation.
    ///
    /// If this fails, `self` is unchanged.
    pub fn from_vulcan_00t(data: &[u8]) -> Result<TriangleMeshSurface, String> {
        let tri = geom::io::trimesh::from_vulcan_00t(data).map_err(|e| e.to_string())?;
        let translate = tri.aabb().origin;
        let (points, indices) = tri.decompose();

        let points = points
            .into_iter()
            .flat_map(|p| p.sub(translate).map(|x| x as f32))
            .collect();
        let indices = indices
            .into_iter()
            .flat_map(|(a, b, c)| [a, b, c])
            .collect();
        let translate = translate.into();

        Ok(Self {
            translate,
            points,
            indices,
        })
    }

    /// Given the data `extents`, returns a list of tile indices that intersect the mesh's
    /// AABB.
    ///
    /// Note that the _mesh_ might not intersect the tile, but it's AABB does.
    pub fn tiles(&self, extents: &Extents3) -> Vec<u32> {
        let aabb = geom::Extents2::from(self.aabb());

        (0u32..)
            .map(|idx| (idx, tile_extents(idx, extents)))
            .take_while(|(_, x)| x.is_some())
            .filter_map(|(idx, e)| {
                e.is_some_and(|e| aabb.intersects(Extents2::from(e)))
                    .then_some(idx)
            })
            .collect()
    }

    pub fn generate_tiles_hash(&self, extents: &Extents3) -> TileHash {
        // the goal here is to loop through the triangles **once**.
        // each triangle's aabb can give use the intersecting tile indices we need to add to

        let [dx, _] = extent_dims(extents);
        let extents = *extents;
        let extents2 = Extents2::from(extents);

        let mut tiles: HashMap<u32, Vec<_>> = HashMap::default();

        for tri in self.tris() {
            let aabb = Extents2::from(tri.aabb());
            if !aabb.intersects(extents2) {
                continue;
            }

            let [minx, miny] = aabb
                .origin
                .sub(extents2.origin)
                .xfm(extents2.size, |a, b| a.clamp(0.0, b))
                .map(|x| (x / TILE_SIZE).floor() as u32)
                // we extend the lower bound down by one to catch boundary conditions
                .map(|x| x.saturating_sub(1));
            // note we take ceiling here and floor before
            let [maxx, maxy] = aabb
                .max()
                .sub(extents2.origin)
                .xfm(extents2.size, |a, b| a.clamp(0.0, b))
                .map(|x| (x / TILE_SIZE).ceil() as u32);

            for idx in (minx..=maxx).flat_map(|x| (miny..=maxy).map(move |y| dx * y + x)) {
                tiles.entry(idx).or_default().push(tri);
            }
        }

        TileHash { tiles, extents }
    }
}

impl TriangleMeshSurface {
    /// Returns in _real_ space.
    fn tris(&self) -> impl ExactSizeIterator<Item = Tri> + '_ {
        use std::ops::Range;

        let ps = self.points.as_slice();
        let translate = geom::Point3::from(self.translate);

        self.indices.chunks_exact(3).map(move |x| {
            let x: [u32; 3] = x.try_into().expect("size 3");
            // to get the point, we take idx * 3..+3
            x.map(|x| {
                <[f32; 3]>::try_from(
                    &ps[Range {
                        start: x as usize * 3,
                        end: (x + 1) as usize * 3,
                    }],
                ) // gets the f32 point
                .expect("3 coordinates")
                .map(|x| x as f64)
                // translate back to real space
                .add(translate)
            })
        })
    }
}

wasm_bindgen_store_impl!(TriangleMeshSurface);
impl Store for TriangleMeshSurface {
    /// Serialize the mesh into binary data.
    ///
    /// See [`Self::from_bytes`] for the format.
    fn to_bytes(&self) -> Vec<u8> {
        let Self {
            points,
            indices,
            translate,
        } = self;

        let mut buf = Vec::new();

        // first write the translation point
        buf.extend(translate.x.to_be_bytes());
        buf.extend(translate.y.to_be_bytes());
        buf.extend(translate.z.to_be_bytes());

        // next write the points
        buf.extend((points.len() as u64).to_be_bytes());
        buf.extend(points.iter().copied().flat_map(f32::to_be_bytes));

        // finally write the indices
        buf.extend((indices.len() as u64).to_be_bytes());
        buf.extend(indices.iter().copied().flat_map(u32::to_be_bytes));

        buf
    }

    /// Deserialize a mesh from binary data.
    ///
    /// # Format
    /// The format is extremely simple and conducive compression over the wire.
    /// **All encoding is done in Big Endian.**
    /// ```plaintext
    /// 8 bytes: translate.x      (f64)
    /// 8 bytes: translate.y      (f64)
    /// 8 bytes: translate.z      (f64)
    /// 8 bytes: points.len()     (u64)
    /// for n in 0..points.len()
    ///     4 bytes: point data   (f32)
    /// 8 bytes: indices.len()    (u64)
    /// for n in 0..indices.len()
    ///     4 bytes: index data   (u32)
    /// ```
    fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        let mut d = StoreDecoder::new(bytes);

        let translate = Point3 {
            x: d.f64()?,
            y: d.f64()?,
            z: d.f64()?,
        };

        let n = d.u64()? as usize;
        let mut points = Vec::with_capacity(n);
        for _ in 0..n {
            points.push(d.f32()?);
        }

        let n = d.u64()? as usize;
        let mut indices = Vec::with_capacity(n);
        for _ in 0..n {
            indices.push(d.u32()?);
        }

        Ok(TriangleMeshSurface {
            translate,
            points,
            indices,
        })
    }
}

struct StoreDecoder<'a>(std::io::Cursor<&'a [u8]>);

impl<'a> StoreDecoder<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        StoreDecoder(std::io::Cursor::new(bytes))
    }

    fn decode<const D: usize, F, T>(&mut self, cnv: F) -> Result<T, String>
    where
        F: FnOnce([u8; D]) -> T,
    {
        use std::io::Read;
        let mut b = [0u8; D];
        self.0
            .read_exact(&mut b)
            .map(|_| cnv(b))
            .map_err(|e| e.to_string())
    }

    fn f32(&mut self) -> Result<f32, String> {
        self.decode(f32::from_be_bytes)
    }

    fn f64(&mut self) -> Result<f64, String> {
        self.decode(f64::from_be_bytes)
    }

    fn u32(&mut self) -> Result<u32, String> {
        self.decode(u32::from_be_bytes)
    }

    fn u64(&mut self) -> Result<u64, String> {
        self.decode(u64::from_be_bytes)
    }
}

#[wasm_bindgen]
pub struct TileHash {
    tiles: HashMap<u32, Vec<Tri>>,
    extents: Extents3,
}

#[wasm_bindgen]
impl TileHash {
    pub fn tiles(&self) -> Vec<u32> {
        self.tiles.keys().copied().collect()
    }

    /// Samples the mesh within a tile at the given spacing.
    pub fn sample(&self, spacing: f64, tile_idx: u32) -> Option<Vec<f32>> {
        let tris = self.tiles.get(&tile_idx).filter(|x| !x.is_empty())?;

        let aabb = Extents2::from(tile_extents(tile_idx, &self.extents)?);
        let grid = Grid::sample_with_bounds(tris.iter().copied(), spacing, true, aabb);

        if grid.is_blank() {
            None
        } else {
            let scaler = self.extents.max_dim();
            let z = self.extents.origin.z;
            grid.into_zs()
                .into_iter()
                .map(|x| x.map(|x| ((x - z) / scaler) as f32).unwrap_or(f32::NAN))
                .collect::<Vec<_>>()
                .into()
        }
    }
}

#[wasm_bindgen]
pub struct ViewableTiles {
    scaler: f64,
    dims: [u32; 2],
    in_view: Vec<TileLod>,
}

#[wasm_bindgen]
impl ViewableTiles {
    pub fn new(extents: &Extents3) -> Self {
        let dims = extent_dims(extents);
        let scaler = extents.max_dim();
        Self {
            scaler,
            dims,
            in_view: Vec::new(),
        }
    }

    /// Calculate the tiles/lods in view and store them internally.
    ///
    /// The `viewbox_extents` is the AABB of **render space** in camera view.
    /// The `camera_dir` is a **render space** vector of the camera view direction.
    pub fn update(&mut self, viewbox: &Viewbox) {
        // we actually do not need to move into world coordinates to work out tile indices
        // instead, leverage that TILE_SIZE / scaler will be a tile size in render space
        // NOTE: render space Y is Z
        let tsize = TILE_SIZE / self.scaler;

        // LOD resolution
        // world area
        let area = viewbox.render_area * self.scaler * self.scaler;
        // console::debug_1(&format!("{area:.0}").into());
        let lod_res = area.powf(0.5) / 400.0;

        let extents = Extents2::from_iter(viewbox.min_ps.into_iter().chain(viewbox.max_ps));

        let [x, y] = extents
            .origin
            .map(|x| (x.clamp(0., 1.) as f64 / tsize).floor() as u32);
        let [x_, y_] = extents
            .max()
            .map(|x| (x.clamp(0., 1.) as f64 / tsize))
            .min_all(self.dims.map(|x| x as f64)) // clamp to tile dims
            .map(|x| x.ceil() as u32);

        let stride = self.dims[0];
        self.in_view.clear();
        self.in_view.extend(
            (x..x_)
                .flat_map(|x| (y..y_).map(move |y| y * stride + x))
                .map(|tile_idx| TileLod { tile_idx, lod_res }),
        );
    }

    pub fn in_view_tiles(&self) -> Vec<u32> {
        self.in_view.iter().map(|x| x.tile_idx).collect()
    }

    pub fn in_view_lods(&self) -> Vec<f64> {
        self.in_view.iter().map(|x| x.lod_res).collect()
    }
}

struct TileLod {
    pub tile_idx: u32,
    pub lod_res: f64,
}

#[wasm_bindgen]
#[derive(Default)]
pub struct VertexData {
    positions: Vec<f32>,
    indices: Vec<u32>,
    normals: Vec<f32>,
}

type VertexDataPts = Vec<Option<(u32, geom::Point3)>>;

#[wasm_bindgen]
impl VertexData {
    /// Fills the component buffers of a babylonjs VertexData with a tile's meshes.
    ///
    /// This has quite a few semantics:
    /// - the grid x/y's are generated on the fly (in render space)
    ///   - (we assumes the zs are in render space)
    /// - the buffers are filled such that we are in _Y-up_ land
    /// - any `NaN`s are assumed nulls
    ///
    /// > _Consumes `zs` in the process, so it will not be available in JS afterwards._
    pub fn fill_vertex_data_from_tile_zs_smooth(
        extents: &Extents3,
        tile_idx: u32,
        zs: Vec<f32>,
    ) -> Self {
        let zs_len = zs.len();
        let size = Self::calc_tile_size(zs_len);
        let pts = Self::build_points(extents, tile_idx, zs);

        // if every grid cell is filled with 2 triangles
        let max_tri_len = size.saturating_sub(1).pow(2) * 2;
        let mut this = Self {
            positions: pts
                .iter()
                .filter_map(|x| *x)
                .flat_map(|x| x.1.map(|x| x as f32))
                .collect(),
            indices: Vec::with_capacity(max_tri_len * 3),
            normals: Vec::new(),
        };

        this.add_indices_smooth(&pts);
        this.add_normals_smooth();

        this
    }

    fn calc_tile_size(zs_len: usize) -> usize {
        // assume the tile is always square.
        (zs_len as f64).sqrt() as usize
    }

    fn build_points(extents: &Extents3, tile_idx: u32, zs: Vec<f32>) -> VertexDataPts {
        let scaler = extents.max_dim();
        let Some(tile_extents) = tile_extents(tile_idx, extents).map(Extents2::from) else { return Default::default(); };
        let extents = Extents2::from(*extents);

        let size = Self::calc_tile_size(zs.len());
        let dsize = TILE_SIZE / (size.saturating_sub(1) as f64);
        let dsize = dsize / scaler;

        // compute the tile extents in render space
        // note that every goes from data extents zero
        let [ox, oy] = tile_extents
            .origin
            .sub(extents.origin)
            .scale(scaler.recip());

        // build a list of indices to points -- note x order
        let mut i = 0;
        let mut pts = Vec::with_capacity(zs.len());
        for y in 0..size {
            let py = oy + dsize * y as f64;
            for x in 0..size {
                let z = zs[y * size + x];
                let p = z.is_finite().then(|| {
                    // capture and increment counter
                    let idx = i;
                    i += 1;
                    let px = ox + dsize * x as f64;
                    // NOTE: we are working in _Y-up_ land, so z/y are swapped
                    (idx, [px, z as f64, py])
                });
                pts.push(p);
            }
        }

        pts
    }

    fn add_indices_smooth(&mut self, pts: &VertexDataPts) {
        let size = Self::calc_tile_size(pts.len());

        // we consider each grid cell by its lower left hand point
        for y in 0..size.saturating_sub(1) {
            for x in 0..size.saturating_sub(1) {
                let bl = y * size + x;
                let br = bl + 1; // +1 in x
                let tl = (y + 1) * size + x;
                let tr = tl + 1;
                let x = [pts[bl], pts[br], pts[tl], pts[tr]].map(|x| x.map(|x| x.0));

                match x {
                    [Some(bl), Some(br), Some(tl), Some(tr)] => {
                        // all four points are real, we generate 2 triangles
                        // bl->br->tr
                        self.indices.extend([bl, br, tr]);
                        // tr->tl->bl
                        self.indices.extend([tr, tl, bl]);
                    }
                    [Some(bl), Some(br), Some(tl), None] => {
                        // tl->bl->br
                        self.indices.extend([tl, bl, br])
                    }
                    [Some(bl), Some(br), None, Some(tr)] => {
                        // bl->br->tr
                        self.indices.extend([bl, br, tr])
                    }
                    [Some(bl), None, Some(tl), Some(tr)] => {
                        // tr->tl->bl
                        self.indices.extend([tr, tl, bl])
                    }
                    [None, Some(br), Some(tl), Some(tr)] => {
                        // br->tr->tl
                        self.indices.extend([br, tr, tl]);
                    }
                    _ => (), // need at least 3 points to make a tri
                }
            }
        }
    }

    /// Requires that positions and indices are set.
    fn add_normals_smooth(&mut self) {
        let mut normals = vec![geom::Point3::zero(); self.positions.len() / 3];

        for face in self.indices.chunks_exact(3) {
            let face: [u32; 3] = face.try_into().unwrap();
            let face = face.map(|x| x as usize);
            let [pa, pb, pc] = face.map(|x| {
                let p: [f32; 3] = self.positions[x * 3..x * 3 + 3].try_into().unwrap();
                p.map(|x| x as f64)
            });
            let [a, b, c] = face;

            let xp = xprod(pc.sub(pa), pb.sub(pa));
            normals[a] = normals[a].add(xp);
            normals[b] = normals[b].add(xp);
            normals[c] = normals[c].add(xp);
        }

        self.normals = normals
            .into_iter()
            .flat_map(|x| x.unit().map(|x| x as f32))
            .collect();
    }

    /// Similar to `fill_vertex_data_from_tile_zs_smooth` except we use a 'flat' shading which
    /// means positions are duplicated and each facet gets a normal (rather than each vertex).
    pub fn fill_vertex_data_from_tile_zs_flat(
        extents: &Extents3,
        tile_idx: u32,
        zs: Vec<f32>,
    ) -> Self {
        let build_pt = |i: usize, x: f32, y: f32| {
            let z = zs[i];
            // NOTE: we are working in _Y-up_ land, so z/y are swapped
            z.is_finite().then_some([x, z, y])
        };

        let scaler = extents.max_dim();
        let Some(tile_extents) = tile_extents(tile_idx, extents).map(Extents2::from) else { return Self::default(); };
        let extents = Extents2::from(*extents);

        // assume the tile is always square.
        let size = (zs.len() as f64).sqrt() as usize;
        let dsize = TILE_SIZE as f32 / (size.saturating_sub(1) as f32);
        let dsize = dsize / scaler as f32;

        // compute the tile extents in render space
        // note that every goes from data extents zero
        let [ox, oy] = tile_extents
            .origin
            .sub(extents.origin)
            .scale(scaler.recip())
            .map(|x| x as f32);

        // if every grid cell is filled with 2 triangles
        let max_tri_len = size.saturating_sub(1).pow(2) * 2;
        let mut this = Self {
            positions: Vec::with_capacity(max_tri_len * 3 * 3),
            indices: Vec::with_capacity(max_tri_len * 3),
            normals: Vec::with_capacity(max_tri_len * 3 * 3),
        };

        // we consider each grid cell by its lower left hand point
        for x in 0..size.saturating_sub(1) {
            let xl = ox + dsize * x as f32;
            let xr = ox + dsize * (x + 1) as f32;

            for y in 0..size.saturating_sub(1) {
                let yb = oy + dsize * y as f32;
                let yt = oy + dsize * (y + 1) as f32;

                let bl = y * size + x;
                let br = bl + 1; // +1 in x
                let tl = (y + 1) * size + x;
                let tr = tl + 1;
                let x = [
                    build_pt(bl, xl, yb),
                    build_pt(br, xr, yb),
                    build_pt(tl, xl, yt),
                    build_pt(tr, xr, yt),
                ];

                match x {
                    [Some(bl), Some(br), Some(tl), Some(tr)] => {
                        // all four points are real, we generate 2 triangles
                        // bl->br->tr
                        this.add_tri_flat([bl, br, tr]);
                        // tr->tl->bl
                        this.add_tri_flat([tr, tl, bl]);
                    }
                    [Some(bl), Some(br), Some(tl), None] => {
                        // tl->bl->br
                        this.add_tri_flat([tl, bl, br])
                    }
                    [Some(bl), Some(br), None, Some(tr)] => {
                        // bl->br->tr
                        this.add_tri_flat([bl, br, tr])
                    }
                    [Some(bl), None, Some(tl), Some(tr)] => {
                        // tr->tl->bl
                        this.add_tri_flat([tr, tl, bl])
                    }
                    [None, Some(br), Some(tl), Some(tr)] => {
                        // br->tr->tl
                        this.add_tri_flat([br, tr, tl])
                    }
                    _ => (), // need at least 3 points to make a tri
                }
            }
        }

        this
    }

    /// To keep consistency with the normals, keep winding to counter-clockwise.
    fn add_tri_flat(&mut self, tri: [[f32; 3]; 3]) {
        let normal = Plane::from(tri.map(|x| x.map(|x| x as f64)))
            .normal()
            .scale(-1.0) // rev direction
            .unit()
            .map(|x| x as f32);
        let [a, b, c] = tri;

        self.positions.extend(a);
        self.indices.push(self.indices.len() as u32);
        self.normals.extend(normal);

        self.positions.extend(b);
        self.indices.push(self.indices.len() as u32);
        self.normals.extend(normal);

        self.positions.extend(c);
        self.indices.push(self.indices.len() as u32);
        self.normals.extend(normal);
    }

    pub fn is_empty(&self) -> bool {
        self.positions.is_empty() || self.normals.is_empty()
    }

    pub fn positions(&self) -> Vec<f32> {
        self.positions.clone()
    }

    pub fn indices(&self) -> Vec<u32> {
        self.indices.clone()
    }

    pub fn normals(&self) -> Vec<f32> {
        self.normals.clone()
    }
}

/// The camera's view box in **render space**.
///
/// To build the view box, one can imagine the viewport defines 4 planes parallel to the camera
/// direction. These intersect with the min/max z world extents.
#[wasm_bindgen]
#[derive(Debug)]
pub struct Viewbox {
    min_ps: [Point2; 4],
    max_ps: [Point2; 4],
    render_area: f64,
}

#[wasm_bindgen]
impl Viewbox {
    /// Build the viewbox.
    ///
    /// Unfortunately the interface is wonky to reduce the amount of serialisation that
    /// must pass through the WASM boundary.
    /// As such there are two arguments.
    /// The first one is the **data extents** in **world space**.
    /// The second is an array of floats representing **points in render space**,
    /// which will be destructured into:
    /// - camera direction
    /// - viewport (bottom-left)
    /// - viewport (bottom-right)
    /// - viewport (top-right)
    /// - viewport (top-left)
    ///
    /// That is, we expect an array of length 15 floats.
    /// If the length is not 15, we panic which will give weird WASM errors or might even
    /// silently fail.
    pub fn calculate(extents: &Extents3, data: &[f64]) -> Self {
        use geom::Point3 as P;

        let camera_dir = P::unit(data[..3].try_into().unwrap());
        let r1: P = data[3..6].try_into().unwrap();
        let r2: P = data[6..9].try_into().unwrap();
        let r3: P = data[9..12].try_into().unwrap();
        let r4: P = data[12..].try_into().unwrap();

        // area is magnitude of cross product!
        // assume sides of rectangle are 1->2 and 1->4
        let area = xprod(r2.sub(r1), r4.sub(r1)).mag();

        let cy = camera_dir[1];
        let prj = |z| {
            [r1, r2, r3, r4].map(|r| {
                let d = (z - r[1]) / cy;
                let [x, _, z] = r.add(camera_dir.scale(d));
                [x, z]
            })
        };

        let max_y = extents.size.z / extents.max_dim();
        let min_ps = prj(0.0);
        let max_ps = prj(max_y);

        Self {
            min_ps,
            max_ps,
            render_area: area,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn assert_tris_fn() {
        let mesh = TriangleMeshSurface {
            translate: [1., 2., 3.].into(),
            points: vec![0., 0., 0., 1., 0., 1., 1., 1., 1., 0., 1., 0.],
            indices: vec![0, 1, 2, 0, 3, 2],
        };

        let tris = mesh.tris().collect::<Vec<_>>();
        assert_eq!(
            tris,
            vec![
                [[1., 2., 3.], [2., 2., 4.], [2., 3., 4.]],
                [[1., 2., 3.], [1., 3., 3.], [2., 3., 4.]]
            ]
        )
    }
}
