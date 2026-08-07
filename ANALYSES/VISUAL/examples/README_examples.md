# Importing FONDUTA
In order to use all the functions in the FONDUTA packages (including the external libraries) we need to first add it to the path at the beginning of each script, e.g.

```matlab
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));
```

After that we can call or get help for one specific function, e.g.
```matlab
help fonduta.viz.view_glm

results_dir='/data06/fUSIMethodsPaper/Data_analysis/sub-Group/VisualTest/Functional/LC'
fonduta.viz.view_glm(fullfile(results_dir, 'glm_run-142136.mat'));
```


# Load preprocessed data
The initial method for loading data uses a single `Datapath.m` script with an argument referring to the experiment whose data we want to load, e.g. `VisualTest`.

This file has now been moved to `FONDUTA.fonduta.io.datapath.Datapath.m`.

```matlab
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

[subDataPath, subAnatPath, resultPath] = fonduta.io.datapath.Datapath('VisualTest');
anatPath = subAnatPath{1}
load(fullfile(anatPath, 'anatomic.mat'), 'anatomic')
fonduta.viz.view_image(anatomic.Data, [], 3)    % 3 = coronal

```


# Transformations 
## Individual -> Atlas
During acquisition, the 4x4 affine transformation matrix is estimated manually by overlapping the `anatomic` onto the allen atlas. This individual-to-atlas transformation is saved in `Transformation.mat`

To warp the individual volume into atlas space, we use `fonduta.atlas.individual2atlas()`. Nearest neighbour interpolation is used.

```matlab
output_anatomic2atlas = fonduta.atlas.individual2atlas(anatomic, atlas, Transf);
```

The `output_anatomic2atlas` has the dimensions of the atlas: 160x264x228

## Atlas -> Individual
Here we pass _the same `Transf` matrix_, but of course since we need to go from atlas to individual, internally the code uses the inverse of this transformation matrix.

```matlab
output_atlas2anatomic = fonduta.atlas.atlas2individual(atlas, anatomic, Transf)
```

The `output_atlas2anatomic` has the dimensions of the anatomic volume, e.g. 158x90x19.


## Optional arguments
In all cases, the entire volume is warped. This is the same as specifying the option `mode` to `volume`, which is the default. If the initial image to be warped is a single slice, it is first embedded in an empty volume, and then warped. 

If `mode` is set to `slice`, the fn reads the slice the experimenter selected for fusi acquisition in `anatomic.funcSlice(3)`, embed this in an empty volume of `size(anatomic.Data)` and warps this in atlas space after 3D interpolation in the voxel size of the allen atlas. 

It is also possible to save a nifti version of the warped volume/slice. The names for these volumes are standard: `anatomic_in_atlas.nii.gz` and `*`


Below there is an example call using these two optional arguments. See `eg_transformations.m` for more.

```matlab
output_anatomic2atlas = fonduta.atlas.individual2atlas( ...
    anatomic, atlas, Transf, ...
    'mode',       'volume', ...
    'save_nifti', true, ...
    'nifti_path', fullfile(outDir, 'anatomic_in_atlas.nii.gz') ...
    );
```

# Visualization

## `view_image()` - Simple Image + overlay
- Simple tool to inspect an image and optionally an overlay.
- Expects 3D or 2D matrices as input
- The last number controls the orientation 1/2/3 = ax/cor/sag
- Mouse wheel to scroll across slices

```matlab
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

atlas = fonduta.atlas.load_atlas()
fonduta.viz.view_image(atlas.Histology, atlas.Regions, 2)
```

## `view_registration()` - View images in allen space
- Useful for checking registration and regions name
- Inputs: the atlas struct + an image which _must_ be in atlas space
- Atlas on the left, image on the right
- Switch between histology, vasculature, regions
- Display image lines on both images
- Click on a voxel to 
    - move the crosshair to the same location in both images
    - get info about the region name and acronym 

```matlab
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

atlas = fonduta.atlas.load_atlas()

[subDataPath, subAnatPath, resultPath] = fonduta.io.datapath.Datapath('VisualTest');
anatPath = subAnatPath{1}

load(fullfile(anatPath, 'anatomic.mat'),       'anatomic');
load(fullfile(anatPath, 'Transformation.mat'), 'Transf');

output_anatomic2atlas = fonduta.atlas.individual2atlas(anatomic, atlas, Transf);

fonduta.viz.view_registration(atlas, output_anatomic2atlas)
```