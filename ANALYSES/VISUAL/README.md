
# Running the matlab scripts from the terminal in parallel

```bash

# M1_StimOnly
# M5_Behavior
# M8_SteadyVisual

cd /data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL

GLM_PATH='/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest'
MODEL_NAME='M5_Behavior'

nohup matlab -nodisplay -nosplash -r \
  "analysis_ridge_loo_ROI('${GLM_PATH}', '${MODEL_NAME}', struct()); exit" \
  > ${MODEL_NAME}.log 2>&1 &


```