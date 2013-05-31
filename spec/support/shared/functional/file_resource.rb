#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

shared_context "deploying with move" do
  before do
    @original_atomic_update = Chef::Config[:file_atomic_update]
    Chef::Config[:file_atomic_update] = true
  end

  after do
    Chef::Config[:file_atomic_update] = @original_atomic_update
  end
end

shared_context "deploying with copy" do
  before do
    @original_atomic_update = Chef::Config[:file_atomic_update]
    Chef::Config[:file_atomic_update] = false
  end

  after do
    Chef::Config[:file_atomic_update] = @original_atomic_update
  end
end

shared_context "deploying via tmpdir" do
  before do
    @original_stage_via = Chef::Config[:file_staging_uses_destdir]
    Chef::Config[:file_staging_uses_destdir] = false
  end

  after do
    Chef::Config[:file_staging_uses_destdir] = @original_stage_via
  end
end

shared_context "deploying via destdir" do
  before do
    @original_stage_via = Chef::Config[:file_staging_uses_destdir]
    Chef::Config[:file_staging_uses_destdir] = true
  end

  after do
    Chef::Config[:file_staging_uses_destdir] = @original_stage_via
  end
end


shared_examples_for "a file with the wrong content" do
  before do
    # Assert starting state is as expected
    File.should exist(path)
    # Kinda weird, in this case @expected_checksum is the cksum of the file
    # with incorrect content.
    sha256_checksum(path).should == @expected_checksum
  end

  include_context "diff disabled"

  context "when running action :create" do
    context "with backups enabled" do
      before do
        Chef::Config[:file_backup_path] = CHEF_SPEC_BACKUP_PATH
        resource.run_action(:create)
      end

      it "overwrites the file with the updated content when the :create action is run" do
        File.stat(path).mtime.should > @expected_mtime
        sha256_checksum(path).should_not == @expected_checksum
      end

      it "backs up the existing file" do
        Dir.glob(backup_glob).size.should equal(1)
      end

      it "is marked as updated by last action" do
        resource.should be_updated_by_last_action
      end

      it "should restore the security contexts on selinux", :selinux_only do
        selinux_security_context_restored?(path).should be_true
      end
    end

    context "with backups disabled" do
      before do
        Chef::Config[:file_backup_path] = CHEF_SPEC_BACKUP_PATH
        resource.backup(0)
        resource.run_action(:create)
      end

      it "should not attempt to backup the existing file if :backup == 0" do
        Dir.glob(backup_glob).size.should equal(0)
      end

      it "should restore the security contexts on selinux", :selinux_only do
        selinux_security_context_restored?(path).should be_true
      end
    end
  end

  describe "when running action :create_if_missing" do
    before do
      resource.run_action(:create_if_missing)
    end

    it "doesn't overwrite the file when the :create_if_missing action is run" do
      File.stat(path).mtime.should == @expected_mtime
      sha256_checksum(path).should == @expected_checksum
    end

    it "is not marked as updated" do
      resource.should_not be_updated_by_last_action
    end

    it "should restore the security contexts on selinux", :selinux_only do
      selinux_security_context_restored?(path).should be_true
    end
  end

  describe "when running action :delete" do
    before do
      resource.run_action(:delete)
    end

    it "deletes the file" do
      File.should_not exist(path)
    end

    it "is marked as updated by last action" do
      resource.should be_updated_by_last_action
    end
  end
end

shared_examples_for "a file with the correct content" do
  before do
    # Assert starting state is as expected
    File.should exist(path)
    sha256_checksum(path).should == @expected_checksum
  end

  include_context "diff disabled"

  describe "when running action :create" do
    before do
      resource.run_action(:create)
    end
    it "does not overwrite the original when the :create action is run" do
      sha256_checksum(path).should == @expected_checksum
    end

    it "does not update the mtime of the file when the :create action is run" do
      File.stat(path).mtime.should == @expected_mtime
    end

    it "is not marked as updated by last action" do
      resource.should_not be_updated_by_last_action
    end

    it "should restore the security contexts on selinux", :selinux_only do
      selinux_security_context_restored?(path).should be_true
    end
  end

  describe "when running action :create_if_missing" do
    before do
      resource.run_action(:create_if_missing)
    end

    it "doesn't overwrite the file when the :create_if_missing action is run" do
      sha256_checksum(path).should == @expected_checksum
    end

    it "is not marked as updated by last action" do
      resource.should_not be_updated_by_last_action
    end

    it "should restore the security contexts on selinux", :selinux_only do
      selinux_security_context_restored?(path).should be_true
    end
  end

  describe "when running action :delete" do
    before do
      resource.run_action(:delete)
    end

    it "deletes the file when the :delete action is run" do
      File.should_not exist(path)
    end

    it "is marked as updated by last action" do
      resource.should be_updated_by_last_action
    end
  end
end

shared_examples_for "a file resource" do
  describe "when deploying with :move" do

    include_context "deploying with move"

    describe "when deploying via tmpdir" do

      include_context "deploying via tmpdir"

      it_behaves_like "a configured file resource"
    end

    describe "when deploying via destdir" do

      include_context "deploying via destdir"

      it_behaves_like "a configured file resource"
    end
  end

  describe "when deploying with :copy" do

    include_context "deploying with copy"

    describe "when deploying via tmpdir" do

      include_context "deploying via tmpdir"

      it_behaves_like "a configured file resource"
    end

    describe "when deploying via destdir" do

      include_context "deploying via destdir"

      it_behaves_like "a configured file resource"
    end
  end

  describe "when running under why run" do

    before do
      Chef::Config[:why_run] = true
    end

    after do
      Chef::Config[:why_run] = false
    end

    context "and the resource has a path with a missing intermediate directory" do
      # CHEF-3978

      let(:path) do
        File.join(test_file_dir, "intermediate_dir", make_tmpname(file_base))
      end

      it "successfully doesn't create the file" do
        resource.run_action(:create) # should not raise
        File.should_not exist(path)
      end
    end

  end

end

shared_examples_for "file resource not pointing to a real file" do
  def symlink?(file_path)
    if windows?
      Chef::ReservedNames::Win32::File.symlink?(file_path)
    else
      File.symlink?(file_path)
    end
  end

  def real_file?(file_path)
    !symlink?(file_path) && File.file?(file_path)
  end

  describe "when force_unlink is set to true" do
    it ":create unlinks the target" do
      real_file?(path).should be_false
      resource.force_unlink(true)
      resource.run_action(:create)
      real_file?(path).should be_true
      binread(path).should == expected_content
      resource.should be_updated_by_last_action
    end
  end

  describe "when force_unlink is set to false" do
    it ":create raises an error" do
      lambda {resource.run_action(:create) }.should raise_error(Chef::Exceptions::FileTypeMismatch)
    end
  end

  describe "when force_unlink is not set (default)" do
    it ":create raises an error" do
      lambda {resource.run_action(:create) }.should raise_error(Chef::Exceptions::FileTypeMismatch)
    end
  end
end

shared_examples_for "a configured file resource" do

  include_context "diff disabled"

  before do
    Chef::Log.level = :info
  end

   # note the stripping of the drive letter from the tmpdir on windows
  let(:backup_glob) { File.join(CHEF_SPEC_BACKUP_PATH, test_file_dir.sub(/^([A-Za-z]:)/, ""), "#{file_base}*") }

  # Most tests update the resource, but a few do not. We need to test that the
  # resource is marked updated or not correctly, but the test contexts are
  # composed between correct/incorrect content and correct/incorrect
  # permissions. We override this "let" definition in the context where content
  # and permissions are correct.
  let(:expect_updated?) { true }

  include Chef::Mixin::ShellOut

  def selinux_security_context_restored?(path)
    @restorecon_path = which("restorecon") if @restorecon_path.nil?
    restorecon_test_command = "#{@restorecon_path} -n -v #{path}"
    cmdresult = shell_out(restorecon_test_command)
    # restorecon will print the required changes to stdout if any is
    # needed
    cmdresult.stdout.empty?
  end

  def binread(file)
    content = File.open(file, "rb") do |f|
      f.read
    end
    content.force_encoding(Encoding::BINARY) if "".respond_to?(:force_encoding)
    content
  end

  context "when the target file is a symlink", :not_supported_on_win2k3 do
    let(:symlink_target) {
      File.join(CHEF_SPEC_DATA, "file-test-target")
    }

    before do
      FileUtils.touch(symlink_target)
    end

    after do
      FileUtils.rm_rf(symlink_target)
    end

    before(:each) do
      if windows?
        Chef::ReservedNames::Win32::File.symlink(symlink_target, path)
      else
        File.symlink(symlink_target, path)
      end
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end

    describe "when symlink target has correct content" do
      before(:each) do
        File.open(symlink_target, "wb") { |f| f.print expected_content }
      end

      it_behaves_like "file resource not pointing to a real file"
    end

    describe "when symlink target has the wrong content" do
      before(:each) do
        File.open(symlink_target, "wb") { |f| f.print "This is so wrong!!!" }
      end

      after(:each) do
        # symlink should never be followed
        binread(symlink_target).should == "This is so wrong!!!"
      end

      it_behaves_like "file resource not pointing to a real file"
    end
  end

  context "when the target file is a directory" do
    before(:each) do
      FileUtils.mkdir_p(path)
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end

    it_behaves_like "file resource not pointing to a real file"
  end

  context "when the target file is a blockdev",:unix_only, :requires_root do
    include Chef::Mixin::ShellOut
    let(:path) do
      File.join(CHEF_SPEC_DATA, "testdev")
    end

    before(:each) do
      result = shell_out("mknod #{path} b 1 2")
      result.stderr.empty?
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end

    it_behaves_like "file resource not pointing to a real file"
  end

  context "when the target file is a chardev",:unix_only, :requires_root do
    include Chef::Mixin::ShellOut
    let(:path) do
      File.join(CHEF_SPEC_DATA, "testdev")
    end

    before(:each) do
      result = shell_out("mknod #{path} c 1 2")
      result.stderr.empty?
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end

    it_behaves_like "file resource not pointing to a real file"
  end

  context "when the target file is a pipe",:unix_only do
    include Chef::Mixin::ShellOut
    let(:path) do
      File.join(CHEF_SPEC_DATA, "testpipe")
    end

    before(:each) do
      result = shell_out("mkfifo #{path}")
      result.stderr.empty?
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end

    it_behaves_like "file resource not pointing to a real file"
  end

  context "when the target file is a socket",:unix_only do
    require 'socket'

    # It turns out that the path to a socket can have at most ~104
    # bytes. Therefore we are creating our sockets in tmpdir so that
    # they have a shorter path.
    let(:test_socket_dir) { File.join(Dir.tmpdir, "sockets") }

    before do
      FileUtils::mkdir_p(test_socket_dir)
    end

    after do
      FileUtils::rm_rf(test_socket_dir)
    end

    let(:path) do
      File.join(test_socket_dir, "testsocket")
    end

    before(:each) do
      UNIXServer.new(path)
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end

    it_behaves_like "file resource not pointing to a real file"
  end

  context "when the target file does not exist" do
    before do
      # Assert starting state is expected
      File.should_not exist(path)
    end

    describe "when running action :create" do
      before do
        resource.run_action(:create)
      end

      it "creates the file when the :create action is run" do
        File.should exist(path)
      end

      it "creates the file with the correct content when the :create action is run" do
        binread(path).should == expected_content
      end

      it "is marked as updated by last action" do
        resource.should be_updated_by_last_action
      end

      it "should restore the security contexts on selinux", :selinux_only do
        selinux_security_context_restored?(path).should be_true
      end
    end

    describe "when running action :create_if_missing" do
      before do
        resource.run_action(:create_if_missing)
      end

      it "creates the file with the correct content" do
        binread(path).should == expected_content
      end

      it "is marked as updated by last action" do
        resource.should be_updated_by_last_action
      end

      it "should restore the security contexts on selinux", :selinux_only do
        selinux_security_context_restored?(path).should be_true
      end
    end

    describe "when running action :delete" do
      before do
        resource.run_action(:delete)
      end

      it "deletes the file when the :delete action is run" do
        File.should_not exist(path)
      end

      it "is not marked updated by last action" do
        resource.should_not be_updated_by_last_action
      end
    end
  end

  # Set up the context for security tests
  def allowed_acl(sid, expected_perms)
    [ ACE.access_allowed(sid, expected_perms[:specific]) ]
  end

  def denied_acl(sid, expected_perms)
    [ ACE.access_denied(sid, expected_perms[:specific]) ]
  end

  def parent_inheritable_acls
    dummy_file_path = File.join(test_file_dir, "dummy_file")
    FileUtils.touch(dummy_file_path)
    dummy_desc = get_security_descriptor(dummy_file_path)
    FileUtils.rm_rf(dummy_file_path)
    dummy_desc
  end

  it_behaves_like "a securable resource without existing target"

  context "when the target file has the wrong content" do
    before(:each) do
      File.open(path, "wb") { |f| f.print "This is so wrong!!!" }
      now = Time.now.to_i
      File.utime(now - 9000, now - 9000, path)

      @expected_mtime = File.stat(path).mtime
      @expected_checksum = sha256_checksum(path)
    end

    describe "and the target file has the correct permissions" do
      include_context "setup correct permissions"

      it_behaves_like "a file with the wrong content"

      it_behaves_like "a securable resource with existing target"
    end

    context "and the target file has incorrect permissions" do
      include_context "setup broken permissions"

      it_behaves_like "a file with the wrong content"

      it_behaves_like "a securable resource with existing target"
    end
  end

  context "when the target file has the correct content" do
    before(:each) do
      File.open(path, "wb") { |f| f.print expected_content }
      now = Time.now.to_i
      File.utime(now - 9000, now - 9000, path)

      @expected_mtime = File.stat(path).mtime
      @expected_checksum = sha256_checksum(path)
    end

    describe "and the target file has the correct permissions" do

      # When permissions and content are correct, chef should do nothing and
      # the resource should not be marked updated.
      let(:expect_updated?) { false }

      include_context "setup correct permissions"

      it_behaves_like "a file with the correct content"

      it_behaves_like "a securable resource with existing target"
    end

    context "and the target file has incorrect permissions" do
      include_context "setup broken permissions"

      it_behaves_like "a file with the correct content"

      it_behaves_like "a securable resource with existing target"
    end
  end

end

shared_context Chef::Resource::File  do
  if windows?
    require 'chef/win32/file'
  end

  # We create the files in a different directory than tmp to exercise
  # different file deployment strategies more completely.
  let(:test_file_dir) do
    if windows?
      File.join(ENV['systemdrive'], "test-dir")
    else
      File.join(CHEF_SPEC_DATA, "test-dir")
    end
  end

  let(:path) do
    File.join(test_file_dir, make_tmpname(file_base))
  end

  before do
    FileUtils::mkdir_p(test_file_dir)
  end

  after(:each) do
    FileUtils.rm_r(path) if File.exists?(path)
    FileUtils.rm_r(CHEF_SPEC_BACKUP_PATH) if File.exists?(CHEF_SPEC_BACKUP_PATH)
  end

  after do
    FileUtils::rm_rf(test_file_dir)
  end
end
