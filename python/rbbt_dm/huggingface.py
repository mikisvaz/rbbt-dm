#{{{ LOAD MODEL

def import_module_class(module, class_name):
    exec(f"from {module} import {class_name}")
    return eval(class_name)

def load_model(task, checkpoint):
    class_name = 'AutoModelFor' + task
    return import_module_class('transformers', class_name).from_pretrained(checkpoint)

def load_tokenizer(task, checkpoint):
    class_name = 'AutoTokenizer'
    return import_module_class('transformers', class_name).from_pretrained(checkpoint)

def load_model_and_tokenizer(task, checkpoint):
    model = load_model(task, checkpoint)
    tokenizer = load_tokenizer(task, checkpoint)
    return model, tokenizer

#{{{ SIMPLE EVALUATE

def forward(model, features):
    return model(**features)

def logits(predictions):
    logits = predictions["logits"]
    return [v.detach().cpu().numpy() for v in logits]

def eval_model(model, tokenizer, texts, return_logits = True):
    features = tokenizer(texts, return_tensors='pt', truncation=True).to(model.device)
    predictions = forward(model, features)
    if (return_logits):
        return logits(predictions)
    else:
        return predictions

#{{{ TRAIN AND PREDICT

def load_tsv(tsv_file):
    from datasets import load_dataset
    return load_dataset('csv', data_files=[tsv_file], sep="\t")

def tsv_dataset(tokenizer, tsv_file):
    dataset = load_tsv(tsv_file)
    tokenized_dataset = dataset.map(lambda example: tokenizer(example["text"], truncation=True) , batched=True)
    return tokenized_dataset

def training_args(*args, **kwargs):
    from transformers import TrainingArguments
    training_args = TrainingArguments(*args, **kwargs)
    return training_args


def train_model(model, tokenizer, training_args, tsv_file):
    from transformers import Trainer

    tokenized_dataset = tsv_dataset(tokenizer, tsv_file)

    trainer = Trainer(
            model,
            training_args,
            train_dataset = tokenized_dataset["train"],
            tokenizer = tokenizer
            )

    trainer.train()

def find_tokens_in_input(dataset, token_ids):
    position_rows = []

    for row in dataset:
        input_ids = row["input_ids"]

        if (not hasattr(token_ids, "__len__")):
            token_ids = [token_ids]

        positions = []
        for token_id in token_ids:

            item_positions = []
            for i in range(len(input_ids)):
                if input_ids[i] == token_id:
                    item_positions.append(i)

            positions.append(item_positions)


        position_rows.append(positions)

    return position_rows



def predict_model(model, tokenizer, training_args, tsv_file, locate_tokens = None):
    from transformers import Trainer

    tokenized_dataset = tsv_dataset(tokenizer, tsv_file)

    trainer = Trainer(
            model,
            training_args,
            tokenizer = tokenizer
            )

    result = trainer.predict(test_dataset = tokenized_dataset["train"])
    if (locate_tokens != None):
        token_ids = tokenizer.convert_tokens_to_ids(locate_tokens)
        token_positions = find_tokens_in_input(tokenized_dataset["train"], token_ids)
        return dict(result=result, token_positions=token_positions)
    else:
        return result

