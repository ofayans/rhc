require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/git_clone'
require 'fileutils'

describe RHC::Commands::GitClone do
  before(:each) do
    FakeFS.activate!
    FakeFS::FileSystem.clear
    user_config
    @instance = RHC::Commands::GitClone.new
    RHC::Commands::GitClone.stub(:new) do
      @instance.stub(:git_config_get) { "" }
      @instance.stub(:git_config_set) { "" }
      Kernel.stub(:sleep) { }
      @instance.stub(:host_exists?) do |host|
        host.match("dnserror") ? false : true
      end
      @instance
    end
  end
  let!(:rest_client){ MockRestClient.new }
  before(:each) do
    @domain = rest_client.add_domain("mockdomain")
    @app = @domain.add_application("app1", "mock_unique_standalone_cart")
  end

  after(:each) do
    FakeFS.deactivate!
  end

  describe 'git-clone' do
    let(:arguments) { ['app', 'git-clone', 'app1'] }

    context "stubbing git_clone_repo" do
      context "reports success successfully" do
        before do
          @instance.stub(:git_clone_repo) do |git_url, repo_dir|
            Dir::mkdir(repo_dir)
            say "Cloned"
            true
          end
        end

        it { expect { run }.should exit_with_code(0) }
        it { run_output.should match("Cloned") }
      end

      context "testing git_clone_deploy_hooks" do
        before do
          @instance.stub(:git_clone_repo) do |git_url, repo_dir|
            FileUtils.mkdir_p "#{repo_dir}/.git/hooks"
            FileUtils.mkdir_p "#{repo_dir}/.openshift/git_hooks"
            FileUtils.touch "#{repo_dir}/.openshift/git_hooks/pre_commit"
            @instance.git_clone_deploy_hooks(repo_dir)
            say "Copied" if File.exists?("#{repo_dir}/.git/hooks/pre_commit")
            true
          end

          # Get around the FakeFS bug (defunkt/fakefs#177) by
          # stubbing the #cp call to inject a expected fs entry
          FileUtils.stub(:cp) do |hook, dir|
            FakeFS::FileSystem.add(
              File.join(dir, File.basename(hook)),
              FakeFS::FileSystem.find(hook))
          end
        end
        it { expect { run }.should exit_with_code(0) }
        it { run_output.should match("Copied") }
      end

      context "reports failure" do
        before{ @instance.stub(:git_clone_repo).and_raise(RHC::GitException) }

        it { expect { run }.should exit_with_code(216) }
        it { run_output.should match("Git returned an error") }
      end
    end
  end
end
