#{{{ LOAD MODEL
import datasets
import rbbt

def import_module_class(module, class_name):
    if (not module == None):
        exec(f"from {module} import {class_name}")
    return eval(class_name)

def load_model(task, checkpoint, **kwargs):
    if (task == None or task == 'Embedding'):
        class_name = 'AutoModel'
        return import_module_class('transformers', class_name).from_pretrained(checkpoint, **kwargs)
    elif (":" in task):
        module, class_name = task.split(":")
        if (task == None):
            module, class_name = None, module
        return import_module_class(module, class_name).from_pretrained(checkpoint, **kwargs)
    else:
        class_name = 'AutoModelFor' + task
        return import_module_class('transformers', class_name).from_pretrained(checkpoint, **kwargs)

def load_tokenizer(checkpoint, **kwargs):
    class_name = 'AutoTokenizer'
    return import_module_class('transformers', class_name).from_pretrained(checkpoint, **kwargs)

def load_model_and_tokenizer(task, checkpoint):
    model = load_model(task, checkpoint)
    tokenizer = load_tokenizer(checkpoint)
    return model, tokenizer

# Not used

#def load_model_and_tokenizer_from_directory(directory):
#    import os
#    import json
#    options_file = os.path.join(directory, 'options.json')
#    f = open(options_file, "r")
#    options = json.load(f.read())
#    f.close()
#    task = options["task"]
#    checkpoint = options["checkpoint"]
#    return load_model_and_tokenizer(task, checkpoint)

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
    tsv = rbbt.tsv(tsv_file)
    print(tsv)
    ds = datasets.Dataset.from_pandas(tsv)
    d = datasets.DatasetDict()
    d["train"] = ds
    return d

def load_json(json_file):
    return datasets.load_dataset('json', data_files=[json_file])

def tokenize_dataset(tokenizer, dataset):
    return dataset.map(lambda subset: subset if ("input_ids" in subset.keys()) else tokenizer(subset["text"], truncation=True), batched=True)

def tsv_dataset(tokenizer, tsv_file):
    dataset = load_tsv(tsv_file)
    return tokenize_dataset(tokenizer, dataset)

def json_dataset(tokenizer, json_file):
    dataset = load_json(json_file)
    return tokenize_dataset(tokenizer, dataset)

def training_args(*args, **kwargs):
    from transformers import TrainingArguments
    training_args = TrainingArguments(*args, **kwargs)
    return training_args

def train_model(model, tokenizer, training_args, dataset, class_weights=None, **kwargs):
    from transformers import Trainer

    # Note: Parameters need to be made contiguous. I'm not sure why they weren't
    for param in model.parameters(): param.data = param.data.contiguous()

    if (isinstance(dataset, str)):
        if (dataset.endswith('.json')):
            tokenized_dataset = json_dataset(tokenizer, dataset)
        else:
            tokenized_dataset = tsv_dataset(tokenizer, dataset)
    else:
        tokenized_dataset = tokenize_dataset(tokenizer, dataset)

    if (not class_weights == None):
        import torch
        from torch import nn

        class WeightTrainer(Trainer):
            def compute_loss(self, model, inputs, return_outputs=False):
                labels = inputs.get("labels")
                # forward pass
                outputs = model(**inputs)
                logits = outputs.get('logits')
                # compute custom loss
                loss_fct = nn.CrossEntropyLoss(weight=torch.tensor(class_weights).to(model.device))
                loss = loss_fct(logits.view(-1, self.model.config.num_labels), labels.view(-1))
                return (loss, outputs) if return_outputs else loss

        trainer = WeightTrainer(
                model,
                training_args,
                train_dataset = tokenized_dataset["train"],
                tokenizer = tokenizer,
                **kwargs
                )
    else:

        trainer = Trainer(
                model,
                training_args,
                train_dataset = tokenized_dataset["train"],
                tokenizer = tokenizer,
                **kwargs
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


def predict_model(model, tokenizer, training_args, dataset, locate_tokens = None):
    from transformers import Trainer

    if (isinstance(dataset, str)):
        if (dataset.endswith('.json')):
            tokenized_dataset = json_dataset(tokenizer, dataset)
        else:
            tokenized_dataset = tsv_dataset(tokenizer, dataset)
    else:
        tokenized_dataset = tokenize_dataset(tokenizer, dataset)

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

def generate(model, tokenizer, texts, **kwargs):
    from transformers import pipeline
    generator = pipeline('text-generation', model=model, tokenizer=tokenizer)
    return generator(texts, max_length=128, **kwargs)[0]['generated_text']
