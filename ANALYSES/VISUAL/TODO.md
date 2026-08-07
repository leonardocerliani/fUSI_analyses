# TODO
- check if the new atlas2individual works with the analysis script and if so delete the _OLE
- refine glm and make examples
- include also the reconstruction and preprocessing (launcher)
- do the ridge regression
- check if it's necessary to have a separate eg_example and a README_examples.md. The latter might suffice. Then the script can be produced using claude from the README.

# Done 7-8-2026

## Transformations
- Finalized `individual2atlas` and `atlas2individual` so that they have the same api. 
- mandatory arguments are `anatomic`, `atlas`, `Transf`
- the transformation can be applied both to slices or to entire volumes
- The can also produce nifti.gz which are by default saved in the same location of the anatomic

## Visualization
- Made fonduta.viz.view_image to view image and optionally overlay
- Made fonduta.viz.view_registration to view atlas and transformed image in the same atlas space

