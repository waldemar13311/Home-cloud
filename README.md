## infrastructure
Base home infrastructure code

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

ansible-galaxy role install -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

### Multipass команды
```bash
multipass list
multipass delete --all --purge
multipass purge
```

### Tofu команды
```bash
tofu destroy -parallelism=1
tofu plan
tofu apply -parallelism=1
```
