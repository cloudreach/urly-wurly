# How easy is it to run images on GCP Cloud Run?

Very. It's very easy. If you are a small shop and you just want to lift your
node-based web-app into a very scalable, easy to maange environement, then this
is for you.

# What does this repo do?

It builds a web container, pushes it to GCP CSR and launches it on GCP Cloud Run.

# I wanna try it!

Sure! You'll need an authenticated GCP login, Cloud Run service enabled and beta tools install for `gcloud`.

```bash
make package deploy
```

