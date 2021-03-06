#!/bin/bash
if [[ $# -eq 0 ]] || [[ $# -eq 1 ]]
then
	echo "run format > ./run_domain_keyword.sh [domain] [keyword]"
	exit 1
elif [[ $# -eq 2 ]]
then
	DOMAIN=$1
	KEYWORD=$2
	VERSION=""
elif [[ $# -eq 3 ]]
then
	DOMAIN=$1
	KEYWORD=$2
	VERSION=$3
fi

GPU_ID='1'
#MUL_GPU=0
NUM_GEN=100000

PATH_DIR=$(realpath .)
PATH_DATA_DIR=$(realpath ../data)

# "${DOMAIN}"
# Multimodal Data
# Train split
'
python -m gpt2_dst.scripts.preprocess_input \
    --input_path_json="${PATH_DATA_DIR}"/simmc_"${DOMAIN}"/"${DOMAIN}"_train_dials.json \
    --output_path_predict="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_train_dials_predict.txt \
    --output_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_train_dials_target.txt \
    --len_context=2 \
    --total \
    --use_multimodal_contexts=1 \
    --output_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json

# Dev split
python -m gpt2_dst.scripts.preprocess_input \
    --input_path_json="${PATH_DATA_DIR}"/simmc_"${DOMAIN}"/"${DOMAIN}"_dev_dials.json \
    --output_path_predict="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_dev_dials_predict.txt \
    --output_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_dev_dials_target.txt \
    --len_context=2 \
    --total \
    --use_multimodal_contexts=1 \
    --input_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \
    --output_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \

# Devtest split
python -m gpt2_dst.scripts.preprocess_input \
    --input_path_json="${PATH_DATA_DIR}"/simmc_"${DOMAIN}"/"${DOMAIN}"_devtest_dials.json \
    --output_path_predict="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_devtest_dials_predict.txt \
    --output_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_devtest_dials_target.txt \
    --len_context=2 \
    --total \
    --use_multimodal_contexts=1 \
    --input_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \
'
# Train ("${DOMAIN}", multi-modal)
python -m gpt2_dst.scripts.run_language_modeling \
    --output_dir="${PATH_DIR}"/gpt2_dst/save/"${DOMAIN}"/"${KEYWORD}""${VERSION}" \
    --model_type=gpt2 \
    --model_name_or_path="${PATH_DIR}"/gpt2_dst/save/fine_tune/checkpoint-32000  \
    --line_by_line \
    --do_train \
    --train_data_file="${PATH_DIR}"/gpt2_dst/data/furniture_total/furniture_train_dials_target.txt \
    --do_eval \
    --eval_data_file="${PATH_DIR}"/gpt2_dst/data/furniture_total/furniture_dev_dials_target.txt \
    --add_special_tokens="${PATH_DIR}"/gpt2_dst/data/furniture/special_tokens.json \
    --evaluate_during_training \
    --num_train_epochs=35 \
    --overwrite_output_dir \
    --gpu_id=$GPU_ID \
    --per_gpu_train_batch_size=24 \
    --per_gpu_eval_batch_size=32 \
    --fp16 \
    --logging_steps=1000 \
    --save_steps=1000

#--add_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \
# Generate sentences ("${DOMAIN}", multi-modal)

CUDA_VISIBLE_DEVICES=$GPU_ID python -m gpt2_dst.scripts.run_generation \
    --model_type=gpt2 \
    --model_name_or_path="${PATH_DIR}"/gpt2_dst/save/"${DOMAIN}"/"${KEYWORD}""${VERSION}" \
    --num_return_sequences=1 \
    --length=100 \
    --gpu_id=$GPU_ID \
    --stop_token="<EOS>" \
    --num_beams=2 \
    --num_gen=$NUM_GEN \
    --prompts_from_file="${PATH_DIR}"/gpt2_dst/data/furniture_total/furniture_devtest_dials_predict.txt \
    --path_output="${PATH_DIR}"/gpt2_dst/results/"${DOMAIN}"/"${KEYWORD}""${VERSION}"/"${DOMAIN}"_devtest_dials_predicted.txt

# Evaluate ("${DOMAIN}, multi-modal)
python -m gpt2_dst.scripts.evaluate \
    --input_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"/"${DOMAIN}"_devtest_dials_target.txt \
    --input_path_predicted="${PATH_DIR}"/gpt2_dst/results/"${DOMAIN}"/"${KEYWORD}""${VERSION}"/"${DOMAIN}"_devtest_dials_predicted_processed.txt \
    --output_path_report="${PATH_DIR}"/gpt2_dst/results/"${DOMAIN}"/"${KEYWORD}""${VERSION}"/"${DOMAIN}"_devtest_dials_report22.json

