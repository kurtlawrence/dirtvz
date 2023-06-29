#[cfg(test)]
extern crate quickcheck;
#[cfg(test)]
#[macro_use(quickcheck)]
extern crate quickcheck_macros;

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

#[cfg(feature = "err-capture")]
fn init_panic_hook() {
    console_error_panic_hook::set_once();
}
#[cfg(not(feature = "err-capture"))]
fn init_panic_hook() {}

const LODS: [f64; 7] = [32.0, 16.0, 8.0, 4.0, 2.0, 1.0, 0.5];

const COUNT: usize = 128;

const MAX_DEPTH: u8 = LODS.len().saturating_sub(1) as u8;

#[inline(always)]
fn tile_size(depth: usize) -> f64 {
    LODS[depth] * COUNT.saturating_sub(1) as f64
}

#[inline(always)]
fn extent_dims(extents: &Extents3) -> [u16; 2] {
    Extents2::from(*extents)
        .size
        .map(|x| (x / tile_size(0)).ceil() as u16)
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

    /// Deserialise a Vulcan 00t triangulation.
    pub fn from_vulcan_00t(data: &[u8]) -> Result<TriangleMeshSurface, String> {
        init_panic_hook();

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

    pub fn generate_tiles_hash(&self, extents: &Extents3) -> TileHash {
        init_panic_hook();
        // the goal here is to minimise intersection testing.
        // there are a few observations:
        // - looping through the triangles is the best filter, since we can quickly narrow
        //   down the tile space
        // - a triangle's aabb within a given root tile can give the **leaf** points that
        //   it overlaps, thie is easily achieved with some index math
        // - each _parent_ of the leaf would get added as well

        let tris = self.tris().collect::<Vec<_>>();
        let mut tiles: HashMap<u32, Vec<usize>> = HashMap::default();
        let roots = TileId::roots(extents);

        let mut buf = Vec::new();

        for (idx, tri) in tris.iter().copied().enumerate() {
            let aabb = Extents2::from(tri.aabb());

            buf.clear();

            for root in &roots {
                let xs = root.extents(extents);
                let Some(mut int) = aabb.intersection(xs) else { continue; };

                // the size will be valid, the origin is now wrt the tile extents
                int.origin = int.origin.sub(xs.origin);

                let res = tile_size(MAX_DEPTH as usize);

                // find the indices that the triangle overlaps
                let [x, y] = int.origin.scale(res.recip()).map(|x| x.floor() as u8);
                let [x_, y_] = int.max().scale(res.recip()).map(|x| x.ceil() as u8);

                for x in x..x_ {
                    for y in y..y_ {
                        let mut t = TileId::from_leaf_index(x, y);
                        t.root = root.root;
                        buf.push(t);
                        while let Some(p) = t.parent() {
                            buf.push(p);
                            t = p;
                        }
                    }
                }
            }

            buf.sort_unstable();
            buf.dedup();
            for t in &buf {
                tiles.entry(t.as_num()).or_default().push(idx);
            }
        }

        TileHash {
            tris,
            tiles,
            extents: *extents,
        }
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
    tris: Vec<Tri>,
    tiles: HashMap<u32, Vec<usize>>,
    extents: Extents3,
}

#[wasm_bindgen]
impl TileHash {
    pub fn tiles(&self) -> Vec<u32> {
        self.tiles.keys().copied().collect()
    }

    /// Samples the mesh within a tile at the given spacing.
    pub fn sample(&self, tile_idx: u32) -> Option<Vec<f32>> {
        init_panic_hook();

        let tris = self.tiles.get(&tile_idx).filter(|x| !x.is_empty())?;

        let tileid = TileId::from_num(tile_idx);
        let aabb = tileid.extents(&self.extents);
        {
            // we cheat a shrink the size a tiny amount to get exactly 128^2 pts
            let x = tileid.extents(&self.extents);
            Extents2 {
                size: x.size.sub(Point2::all(0.001)),
                ..x
            }
        };
        let spacing = tileid.lod_res();
        let grid = Grid::sample_with_bounds(
            tris.iter().copied().map(|x| self.tris[x]),
            spacing,
            true,
            aabb,
        );

        (!grid.is_blank()).then_some(())?; // exit if empty

        assert_eq!(grid.len(), COUNT.pow(2));

        let scaler = self.extents.max_dim();
        let z = self.extents.origin.z;
        grid.into_zs()
            .into_iter()
            .map(|x| x.map(|x| ((x - z) / scaler) as f32).unwrap_or(f32::NAN))
            .collect::<Vec<_>>()
            .into()
    }
}

#[wasm_bindgen]
#[derive(Copy, Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TileId {
    /// The index into the tessellated lowest LOD array.
    root: u16,
    /// The path of the nested quadtree tiles.
    ///
    /// The first 3 bits are used to describe the depth.
    /// The remaining bits are used to describe the path.
    path: u16,
}

#[wasm_bindgen]
impl TileId {
    /// This tile a 'root' tile in the tessellating grid.
    pub fn is_root(id: u32) -> bool {
        Self::from_num(id).is_root_()
    }

    /// This tile a 'root' tile in the tessellating grid.
    pub fn is_root_(&self) -> bool {
        self.lod_lvl() == 0
    }

    /// This tile is at the deepest nesting level.
    pub fn is_max(id: u32) -> bool {
        Self::from_num(id).is_max_()
    }

    /// This tile is at the deepest nesting level.
    pub fn is_max_(&self) -> bool {
        self.lod_lvl() == MAX_DEPTH
    }

    /// Returns the root tiles in that tessellate over the extents.
    fn roots(extents: &Extents3) -> Vec<Self> {
        let [x, y] = extent_dims(extents);
        (0..x * y).map(|root| TileId { root, path: 0 }).collect()
    }

    /// Represent this id as a single number.
    pub fn as_num(&self) -> u32 {
        ((self.root as u32) << 16) | self.path as u32
    }

    pub fn from_num(n: u32) -> Self {
        let root = (n >> 16) as u16;
        let path = (n & (u16::MAX as u32)) as u16;
        Self { root, path }
    }

    pub fn lod_res(&self) -> f64 {
        LODS[self.lod_lvl() as usize]
    }

    pub fn lod_lvl(&self) -> u8 {
        (self.path >> 13) as u8
    }

    fn extents(&self, world: &Extents3) -> Extents2 {
        let TileId { root, path: _ } = *self;
        let [dx, dy] = extent_dims(world);
        let extents = Extents2::from(*world);

        if root > dx * dy {
            Extents2::zero()
        } else {
            let origin = [root % dx, root / dx]
                .map(|x| x as f64)
                .scale(tile_size(0))
                .add(extents.origin)
                .add(self.ovec());

            Extents2 {
                origin,
                size: Point2::all(tile_size(self.lod_lvl().into())),
            }
        }
    }

    /// Return a path iterator.
    fn path_iter(&self) -> impl ExactSizeIterator<Item = [bool; 2]> {
        let mut x = self.path << 3;
        (0..self.lod_lvl()).map(move |_| {
            let y = x >> 14;
            x = x << 2;
            match y {
                0b00 => [false, false],
                0b01 => [false, true],
                0b10 => [true, false],
                0b11 => [true, true],
                _ => unreachable!("should only have 2 bits"),
            }
        })
    }

    /// This is the vector from the root tile's origin to the tile origin.
    fn ovec(&self) -> Point2 {
        self.path_iter()
            .enumerate()
            .fold(Point2::zero(), |p, (i, x)| {
                p.add(x.map(|x| u8::from(x) as f64 * tile_size(i + 1)))
            })
    }

    fn parent(&self) -> Option<Self> {
        if self.is_root_() {
            None
        } else {
            let d = 15 - (self.lod_lvl() * 2);
            let l = (self.lod_lvl() as u16 - 1) << 13;
            let path = ((((self.path << 3) >> 3) | l) >> d) << d;
            Some(Self {
                path,
                root: self.root,
            })
        }
    }

    fn children(&self) -> [Self; 4] {
        let d = self.lod_lvl() as u16;
        let d_ = (d + 1) << 13;
        let TileId { root, path } = *self;
        let f = |n: u16| {
            let path = ((path << 3) >> 3 | d_) | (n << (11 - d * 2));
            Self { root, path }
        };

        [f(0b00), f(0b01), f(0b10), f(0b11)]
    }

    /// This generates a _leaf_ tile from the index with respect to the root tile's origin.
    ///
    /// We can leverage the fact that the indices use powers of 2, so each bit describes
    /// the step in that dimension.
    /// We just need to interleave the x/y together, and we address the depth and padding.
    ///
    /// We can use Morton encoding for this.
    fn from_leaf_index(x: u8, y: u8) -> Self {
        let x = x as u16;
        let y = y as u16;

        let mut path = 0u16;
        for i in 0..MAX_DEPTH {
            let t = (y & 1 << i) << i | (x & 1 << i) << (i + 1);
            path = path | t;
        }

        path = path << 1; // pad
        path = path | 0b110_0000_0000_0000_0; // prefix depth

        Self { root: 0, path }
    }
}

#[wasm_bindgen]
pub struct ViewableTiles {
    extents: Extents3,
    in_view: Vec<u32>,
    out_view: Vec<u32>,
}

#[wasm_bindgen]
impl ViewableTiles {
    pub fn new(extents: &Extents3) -> Self {
        Self {
            extents: *extents,
            in_view: Vec::new(),
            out_view: Vec::new(),
        }
    }

    /// Calculate the tiles/lods in view and store them internally.
    ///
    /// The `viewbox_extents` is the AABB of **render space** in camera view.
    /// The `camera_dir` is a **render space** vector of the camera view direction.
    pub fn update(&mut self, viewbox: &Viewbox) {
        let world = &self.extents;
        let scaler = world.max_dim();

        // LOD resolution
        // world area
        let area = viewbox.render_area * scaler * scaler;
        // console::debug_1(&format!("area {area:.0} | ha {:.0}", area / 10_000.0).into());
        let lod_res = (area / 10_000.0).powf(0.5) / 2.0;
        let lod_depth = choose_lod_depth(lod_res) as u8;

        let extents = Extents2::from_iter(
            viewbox
                .min_ps
                .into_iter()
                .chain(viewbox.max_ps)
                .map(|p| p.scale(scaler).add(world.origin.into())),
        );

        let mut stack = TileId::roots(world);
        self.in_view.clear();
        self.out_view.clear();

        while let Some(t) = stack.pop() {
            let ints = t.extents(world).intersects(extents);
            let at_depth = t.lod_lvl() == lod_depth;

            if ints && at_depth {
                // simply push this tile into view
                self.in_view.push(t.as_num());
            } else if ints {
                // push the child nodes onto the stack
                stack.extend(t.children());
            } else {
                // does not intersect, we add as an out of view
                // note that this would be at the lowest LOD without overlap of inview
                self.out_view.push(t.as_num());
            }
        }
    }

    pub fn in_view_tiles(&self) -> Vec<u32> {
        self.in_view.clone()
    }

    pub fn out_view_tiles(&self) -> Vec<u32> {
        self.out_view.clone()
    }
}

fn choose_lod_depth(resolution: f64) -> usize {
    LODS.into_iter()
        .enumerate()
        .find_map(|(i, res)| (resolution > res).then_some(i))
        .unwrap_or(LODS.len() - 1)
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
        init_panic_hook();

        let tile = TileId::from_num(tile_idx);

        let pts = Self::build_points(extents, tile, zs);

        // if every grid cell is filled with 2 triangles
        let max_tri_len = COUNT.pow(2) * 2;
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

    fn build_points(extents: &Extents3, tile: TileId, zs: Vec<f32>) -> VertexDataPts {
        let scaler = extents.max_dim();
        let tile_extents = tile.extents(extents);
        let extents = Extents2::from(*extents);

        let dsize = tile.lod_res() / scaler;

        // compute the tile extents in render space
        // note that every goes from data extents zero
        let [ox, oy] = tile_extents
            .origin
            .sub(extents.origin)
            .scale(scaler.recip());

        // build a list of indices to points -- note x order
        let mut i = 0;
        let mut pts = Vec::with_capacity(zs.len());
        let stride = COUNT;
        assert_eq!(zs.len(), stride.pow(2));
        for y in 0..stride {
            let py = oy + dsize * y as f64;
            for x in 0..stride {
                let z = zs[y * stride + x];
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
        let stride = COUNT;
        let size = stride - 1;

        // we consider each grid cell by its lower left hand point
        for y in 0..size {
            for x in 0..size {
                let bl = y * stride + x;
                let br = bl + 1; // +1 in x
                let tl = (y + 1) * stride + x;
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

    #[test]
    fn assert_tile_sizing() {
        assert_eq!(tile_size(0), 4096.0);
        assert_eq!(tile_size(1), 2048.0);
        assert_eq!(tile_size(2), 1024.0);
        assert_eq!(tile_size(3), 512.0);
        assert_eq!(tile_size(4), 256.0);
        assert_eq!(tile_size(5), 128.0);
        assert_eq!(tile_size(6), 64.0);
    }

    #[test]
    fn lod_lvl_testing() {
        let f = |path: u16| {
            let x = TileId { root: 0, path };
            (x.lod_lvl(), x.lod_res())
        };

        assert_eq!(f(0b000_0000_0000_0000_0), (0, 32.0));
        assert_eq!(f(0b001_0000_0000_0000_0), (1, 16.0));
        assert_eq!(f(0b010_0000_0000_0000_0), (2, 8.0));
        assert_eq!(f(0b011_0000_0000_0000_0), (3, 4.0));
        assert_eq!(f(0b100_0000_0000_0000_0), (4, 2.0));
        assert_eq!(f(0b101_0000_0000_0000_0), (5, 1.0));
        assert_eq!(f(0b110_0000_0000_0000_0), (6, 0.5));
    }

    #[test]
    fn path_iter_testing() {
        let p = |path: u16| TileId { root: 0, path }.path_iter().collect::<Vec<_>>();

        assert_eq!(p(0b000_0000_0000_0000_0), Vec::<[bool; 2]>::new());
        assert_eq!(p(0b001_0000_0000_0000_0), vec![[false, false]]);
        assert_eq!(p(0b001_1100_0000_0000_0), vec![[true, true]]);
        assert_eq!(p(0b001_1000_0000_0000_0), vec![[true, false]]);
        assert_eq!(
            p(0b110_1001_1100_0110_0),
            vec![
                [true, false],
                [false, true],
                [true, true],
                [false, false],
                [false, true],
                [true, false]
            ]
        );
    }

    #[test]
    fn ovec_testing() {
        let p = |path: u16| TileId { root: 0, path }.ovec();

        assert_eq!(p(0b000_0000_0000_0000_0), [0.0, 0.0]);
        assert_eq!(p(0b001_0000_0000_0000_0), [0.0, 0.0]);
        assert_eq!(p(0b001_1100_0000_0000_0), [2048.0, 2048.0]);
        assert_eq!(p(0b001_1000_0000_0000_0), [2048.0, 0.0]);
        assert_eq!(p(0b110_1001_1100_0110_0), [2624.0, 1664.0]);
    }

    #[quickcheck]
    fn tileid_to_from_num_fuzz(root: u16, path: u16) -> bool {
        let id = TileId { root, path };
        TileId::from_num(id.as_num()) == id
    }

    #[test]
    fn choose_lod_depth_testing() {
        assert_eq!(choose_lod_depth(50.0), 0); // 32   res
        assert_eq!(choose_lod_depth(30.0), 1); // 16   res
        assert_eq!(choose_lod_depth(15.0), 2); //  8   res
        assert_eq!(choose_lod_depth(6.0), 3); //  4   res
        assert_eq!(choose_lod_depth(3.0), 4); //  2   res
        assert_eq!(choose_lod_depth(1.5), 5); //  1   res
        assert_eq!(choose_lod_depth(0.7), 6); //  0.5 res
        assert_eq!(choose_lod_depth(0.1), 6); //  0.5 res
    }

    #[test]
    fn children_testing() {
        let f = |path: u16| TileId { root: 0, path }.children().map(|x| x.path);
        assert_eq!(
            f(0b000_0000_0000_0000_0),
            [
                0b001_0000_0000_0000_0,
                0b001_0100_0000_0000_0,
                0b001_1000_0000_0000_0,
                0b001_1100_0000_0000_0,
            ]
        );
        assert_eq!(
            f(0b011_0110_0100_0000_0),
            [
                0b100_0110_0100_0000_0,
                0b100_0110_0101_0000_0,
                0b100_0110_0110_0000_0,
                0b100_0110_0111_0000_0,
            ]
        );
    }

    #[test]
    fn roots_and_maxs() {
        let f = |path: u16| {
            let x = TileId { root: 0, path };
            (x.is_root_(), x.is_max_())
        };

        assert_eq!(f(0b000_0000_0000_0000_0), (true, false));
        assert_eq!(f(0b001_0000_0000_0000_0), (false, false));
        assert_eq!(f(0b010_0000_0000_0000_0), (false, false));
        assert_eq!(f(0b011_0000_0000_0000_0), (false, false));
        assert_eq!(f(0b100_0000_0000_0000_0), (false, false));
        assert_eq!(f(0b101_0000_0000_0000_0), (false, false));
        assert_eq!(f(0b110_0000_0000_0000_0), (false, true));
    }

    #[test]
    fn leaf_index_to_tileid() {
        let f = |x, y| {
            let x = TileId::from_leaf_index(x, y).path;
            eprintln!("{x:b}");
            x
        };

        assert_eq!(f(0, 0), 0b110_0000_0000_0000_0);
        assert_eq!(f(63, 63), 0b110_1111_1111_1111_0);
        assert_eq!(f(63, 0), 0b110_1010_1010_1010_0);
        assert_eq!(f(0, 63), 0b110_0101_0101_0101_0);
        assert_eq!(f(0b1110, 31), 0b110_0001_1111_1101_0);
    }

    #[test]
    fn parent_testing() {
        let x = TileId {
            root: 1,
            path: 0b110_1111_1111_1111_0,
        };

        let x = x.parent().unwrap();
        assert_eq!(x.path, 0b101_1111_1111_1100_0);
        let x = x.parent().unwrap();
        assert_eq!(x.path, 0b100_1111_1111_0000_0);
        let x = x.parent().unwrap();
        assert_eq!(x.path, 0b011_1111_1100_0000_0);
        let x = x.parent().unwrap();
        assert_eq!(x.path, 0b010_1111_0000_0000_0);
        let x = x.parent().unwrap();
        assert_eq!(x.path, 0b001_1100_0000_0000_0);
        let x = x.parent().unwrap();
        assert_eq!(x.path, 0b000_0000_0000_0000_0);
        let x = x.parent();
        assert_eq!(x, None);
    }
}
