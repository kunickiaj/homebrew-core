require "language/go"

class GitlabRunner < Formula
  desc "The official GitLab CI runner written in Go"
  homepage "https://gitlab.com/gitlab-org/gitlab-runner"
  url "https://gitlab.com/gitlab-org/gitlab-runner.git",
      :tag => "v10.0.0",
      :revision => "2055cfdc9ab6a2ba5aa3a84fe14372cd214e08db"
  head "https://gitlab.com/gitlab-org/gitlab-runner.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "96b7bb2bac51c8494bc760291803846e140a2761e23e48b8b555e39bb2cbfc64" => :high_sierra
    sha256 "3b5f6024763210b3f83a187ff903ded10051c29a974b53d19d74479dfc8df573" => :sierra
    sha256 "810a9b4c7edd299bfc61ad44ceba7208c4e127e44baf778858a6f1af1500d4f8" => :el_capitan
    sha256 "9e7473da8fd43a3025904ff09b2f95eb580d33f0e20c13d909888c2f1a94a768" => :yosemite
  end

  depends_on "go" => :build
  depends_on "docker" => :recommended

  go_resource "github.com/jteeuwen/go-bindata" do
    url "https://github.com/jteeuwen/go-bindata.git",
        :revision => "a0ff2567cfb70903282db057e799fd826784d41d"
  end

  resource "prebuilt-x86_64.tar.xz" do
    url "https://gitlab-runner-downloads.s3.amazonaws.com/v10.0.0/docker/prebuilt-x86_64.tar.xz",
        :using => :nounzip
    version "10.0.0"
    sha256 "9c88e6f924f14ab6802103436bb6419cc4da1c46a77f39a1bc40349abfbf2e8f"
  end

  resource "prebuilt-arm.tar.xz" do
    url "https://gitlab-runner-downloads.s3.amazonaws.com/v10.0.0/docker/prebuilt-arm.tar.xz",
        :using => :nounzip
    version "10.0.0"
    sha256 "9c56f8a58eaec81ed0da6242177672fef28ea49b784abd8e78e69b5d67cde3a7"
  end

  def install
    ENV["GOPATH"] = buildpath
    dir = buildpath/"src/gitlab.com/gitlab-org/gitlab-runner"
    dir.install buildpath.children
    ENV.prepend_create_path "PATH", buildpath/"bin"
    Language::Go.stage_deps resources, buildpath/"src"

    cd "src/github.com/jteeuwen/go-bindata/go-bindata" do
      system "go", "install"
    end

    cd dir do
      Pathname.pwd.install resource("prebuilt-x86_64.tar.xz"),
                           resource("prebuilt-arm.tar.xz")
      system "go-bindata", "-pkg", "docker", "-nocompress", "-nomemcopy",
                           "-nometadata", "-o",
                           "#{dir}/executors/docker/bindata.go",
                           "prebuilt-x86_64.tar.xz",
                           "prebuilt-arm.tar.xz"

      proj = "gitlab.com/gitlab-org/gitlab-runner"
      commit = Utils.popen_read("git", "rev-parse", "--short", "HEAD").chomp
      branch = version.to_s.split(".")[0..1].join("-") + "-stable"
      built = Time.new.strftime("%Y-%m-%dT%H:%M:%S%:z")
      system "go", "build", "-ldflags", <<-EOS.undent
             -X #{proj}/common.NAME=gitlab-runner
             -X #{proj}/common.VERSION=#{version}
             -X #{proj}/common.REVISION=#{commit}
             -X #{proj}/common.BRANCH=#{branch}
             -X #{proj}/common.BUILT=#{built}
      EOS

      bin.install "gitlab-runner"
      prefix.install_metafiles
    end
  end

  plist_options :manual => "gitlab-runner start"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>SessionCreate</key><false/>
        <key>KeepAlive</key><true/>
        <key>RunAtLoad</key><true/>
        <key>Disabled</key><false/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/gitlab-runner</string>
          <string>run</string>
          <string>--working-directory</string>
          <string>#{ENV["HOME"]}</string>
          <string>--config</string>
          <string>#{ENV["HOME"]}/.gitlab-runner/config.toml</string>
          <string>--service</string>
          <string>gitlab-runner</string>
          <string>--syslog</string>
        </array>
      </dict>
    </plist>
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gitlab-runner --version")
  end
end
