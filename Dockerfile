FROM rocker/verse:4.3.3

WORKDIR /work

ENV RENV_CONFIG_REPOS_OVERRIDE=https://cloud.r-project.org

COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R

RUN Rscript -e 'renv::restore(prompt = FALSE)'

COPY . .

RUN Rscript -e 'renv::status()'
