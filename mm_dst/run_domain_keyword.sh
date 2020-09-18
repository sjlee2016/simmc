#!/bin/bash
if [[ $# -eq 0 ]] || [[ $# -eq 1 ]]
then
	echo "run format > ./run_domain_keyword.sh [domain] [keyword]"
	exit 1
else
	DOMAIN=$1
	KEYWORD=$2
fi

GPU_ID=1

PATH_DIR=$(realpath .)
PATH_DATA_DIR=$(realpath ../data)


# "${DOMAIN}"
# Multimodal Data
# Train split
python -m gpt2_dst.scripts.preprocess_input \
    --input_path_json="${PATH_DATA_DIR}"/simmc_"${DOMAIN}"/"${DOMAIN}"_train_dials.json \
    --output_path_predict="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_train_dials_predict.txt \
    --output_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_train_dials_target.txt \
    --len_context=3 \
    --use_multimodal_contexts=1 \
    --output_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json

# Dev split
python -m gpt2_dst.scripts.preprocess_input \
    --input_path_json="${PATH_DATA_DIR}"/simmc_"${DOMAIN}"/"${DOMAIN}"_dev_dials.json \
    --output_path_predict="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_dev_dials_predict.txt \
    --output_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_dev_dials_target.txt \
    --len_context=3 \
    --use_multimodal_contexts=1 \
    --input_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \
    --output_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \

# Devtest split
python -m gpt2_dst.scripts.preprocess_input \
    --input_path_json="${PATH_DATA_DIR}"/simmc_"${DOMAIN}"/"${DOMAIN}"_devtest_dials.json \
    --output_path_predict="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_devtest_dials_predict.txt \
    --output_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_devtest_dials_target.txt \
    --len_context=3 \
    --use_multimodal_contexts=1 \
    --input_path_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \


# Train ("${DOMAIN}", multi-modal)
CUDA_VISIBLE_DEVICES=$GPU_ID python -m gpt2_dst.scripts.run_language_modeling \
    --output_dir="${PATH_DIR}"/gpt2_dst/save/"${DOMAIN}"/"${KEYWORD}" \
    --model_type=gpt2 \
    --model_name_or_path=gpt2 \
    --line_by_line \
    --add_special_tokens="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/special_tokens.json \
    --do_train \
    --train_data_file="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_train_dials_target.txt \
    --do_eval \
    --eval_data_file="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_dev_dials_target.txt \
    --num_train_epochs=5 \
    --overwrite_output_dir \
    --per_gpu_train_batch_size=16 \
    --per_gpu_eval_batch_size=32 \
    --warmup_steps=2000 \
    --save_steps=1000

# Generate sentences ("${DOMAIN}", multi-modal)
CUDA_VISIBLE_DEVICES=$GPU_ID python -m gpt2_dst.scripts.run_generation \
    --model_type=gpt2 \
    --model_name_or_path="${PATH_DIR}"/gpt2_dst/save/"${DOMAIN}"/"${KEYWORD}"\
    --num_return_sequences=1 \
    --length=100 \
    --stop_token='<EOS>' \
    --num_beams=2 \
    --prompts_from_file="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_devtest_dials_predict.txt \
    --path_output="${PATH_DIR}"/gpt2_dst/results/"${DOMAIN}"/"${KEYWORD}"/"${DOMAIN}"_devtest_dials_predicted.txt

# Evaluate ("${DOMAIN}, multi-modal)
python -m gpt2_dst.scripts.evaluate \
    --input_path_target="${PATH_DIR}"/gpt2_dst/data/"${DOMAIN}"_"${KEYWORD}"/"${DOMAIN}"_devtest_dials_target.txt \
    --input_path_predicted="${PATH_DIR}"/gpt2_dst/results/"${DOMAIN}"/"${KEYWORD}"/"${DOMAIN}"_devtest_dials_predicted.txt \
    --output_path_report="${PATH_DIR}"/gpt2_dst/results/"${DOMAIN}"/"${KEYWORD}"/"${DOMAIN}"_devtest_dials_report.json