# Ruby 3.3.6 버전을 기반으로 하는 공식 이미지 사용
FROM ruby:3.3.6

# 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정
WORKDIR /apps
COPY . .

# Gemfile이 있다고 가정하고, 의존성 설치
RUN bundle lock --add-platform x86_64-linux
# COPY Gemfile Gemfile.lock ./
RUN bundle install

# Jekyll 사이트 빌드
RUN jekyll build

# 포트 4000 노출 (Jekyll의 기본 포트)
EXPOSE 4000

# Jekyll 서버 실행
CMD ["jekyll", "serve", "--production", "--host", "0.0.0.0"]
# CMD ["./tools/run.sh", "--production", "--host", "0.0.0.0"]
