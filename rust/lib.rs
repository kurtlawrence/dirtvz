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
    Extents::from(*extents)
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

/// Mirrors the structure of 'ts/data/spatial.ts'
#[wasm_bindgen(inspectable)]
#[derive(Copy, Clone)]
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
#[derive(Copy, Clone)]
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
                .map(|x| (x / TILE_SIZE).ceil() as u32);
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
    pub fn sample(
        &self,
        spacing: f64,
        tile_idx: u32,
    ) -> Option<Vec<f32>> {
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
