#!BuildTag: rmt-ci-container-ruby3.4
#!UseOBSRepositories
FROM opensuse/tumbleweed

RUN zypper --non-interactive install --no-recommends ruby3.4 ruby3.4-devel ruby3.4-rubygem-bundler

RUN zypper --non-interactive install libffi-devel libmysqlclient-devel libxml2-devel \
                        libxslt-devel rpmbuild systemd gzip tar bzip2 nodejs sqlite-devel \
                        make chrpath fdupes gcc libcurl-devel libyaml-devel valkey

RUN rm /usr/bin/ruby /usr/bin/gem

RUN update-alternatives --install /usr/bin/gem gem /usr/bin/gem.ruby3.4 1
RUN update-alternatives --install /usr/bin/gem gem /usr/bin/gem.ruby4.0 2
RUN update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/bundle bundle /usr/bin/bundle.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/bundle bundle /usr/bin/bundle.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/bundler bundler /usr/bin/bundler.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/bundler bundler /usr/bin/bundler.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/racc racc /usr/bin/racc.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/racc racc /usr/bin/racc.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/rake rake /usr/bin/rake.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/rake rake /usr/bin/rake.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/rbs rbs /usr/bin/rbs.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/rbs rbs /usr/bin/rbs.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/rdoc rdoc /usr/bin/rdoc.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/rdoc rdoc /usr/bin/rdoc.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/ri ri /usr/bin/ri.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/ri ri /usr/bin/ri.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/typeprof typeprof /usr/bin/typeprof.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/typeprof typeprof /usr/bin/typeprof.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/rdbg rdbg /usr/bin/rdbg.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/rdbg rdbg /usr/bin/rdbg.ruby.ruby4.0 2
RUN update-alternatives --install /usr/bin/syntax_suggest syntax_suggest /usr/bin/syntax_suggest.ruby.ruby3.4 1
RUN update-alternatives --install /usr/bin/syntax_suggest syntax_suggest /usr/bin/syntax_suggest.ruby.ruby4.0 2

RUN update-alternatives --set ruby /usr/bin/ruby.ruby3.4 && \
    update-alternatives --set gem /usr/bin/gem.ruby3.4 && \
    update-alternatives --set bundle /usr/bin/bundle.ruby.ruby3.4 && \
    update-alternatives --set bundler /usr/bin/bundler.ruby.ruby3.4 && \
    update-alternatives --set racc /usr/bin/racc.ruby.ruby3.4 && \
    update-alternatives --set rake /usr/bin/rake.ruby.ruby3.4 && \
    update-alternatives --set rbs /usr/bin/rbs.ruby.ruby3.4 && \
    update-alternatives --set rdoc /usr/bin/rdoc.ruby.ruby3.4 && \
    update-alternatives --set ri /usr/bin/ri.ruby.ruby3.4 && \
    update-alternatives --set typeprof /usr/bin/typeprof.ruby.ruby3.4 && \
    update-alternatives --set rdbg /usr/bin/rdbg.ruby.ruby3.4 && \
    update-alternatives --set syntax_suggest /usr/bin/syntax_suggest.ruby.ruby3.4

# HACK: Manually set default macros for ruby builds
RUN sed -i -e 's/4\.[0-9]/3\.4/g' -e 's/4[0-9]/34/g' /usr/lib/rpm/macros.d/macros.suse-ruby4.0-default && \
    cp /usr/lib/rpm/macros.d/macros.suse-ruby4.0-default /usr/lib/rpm/macros.d/macros.suse-ruby3.4-default

RUN mkdir /usr/src/rmt-server
WORKDIR /usr/src/rmt-server
