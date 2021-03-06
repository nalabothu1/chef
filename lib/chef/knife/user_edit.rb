#
# Author:: Steven Danna (<steve@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

require 'chef/knife'

class Chef
  class Knife
    class UserEdit < Knife

      deps do
        require 'chef/user'
        require 'chef/json_compat'
      end

      banner "knife user edit USER (options)"

      def osc_11_warning
<<-EOF
The Chef Server you are using does not support the username field.
This means it is an Open Source 11 Server.
knife user edit for Open Source 11 Server is being deprecated.
Open Source 11 Server user commands now live under the knife oc_user namespace.
For backwards compatibility, we will forward this request to knife osc_user edit.
If you are using an Open Source 11 Server, please use that command to avoid this warning.
EOF
      end

      def run_osc_11_user_edit
        # run osc_user_create with our input
        ARGV.delete("user")
        ARGV.unshift("osc_user")
        Chef::Knife.run(ARGV, Chef::Application::Knife.options)
      end

      def run
        @user_name = @name_args[0]

        if @user_name.nil?
          show_usage
          ui.fatal("You must specify a user name")
          exit 1
        end

        original_user = Chef::User.load(@user_name).to_hash
        # DEPRECATION NOTE
        # Remove this if statement and corrosponding code post OSC 11 support.
        #
        # if username is nil, we are in the OSC 11 case,
        # forward to deprecated command
        if original_user["username"].nil?
          ui.warn(osc_11_warning)
          run_osc_11_user_edit
        else # EC / CS 12 user create
          edited_user = edit_data(original_user)
          if original_user != edited_user
            user = Chef::User.from_hash(edited_user)
            user.update
            ui.msg("Saved #{user}.")
          else
            ui.msg("User unchanged, not saving.")
          end
        end

      end
    end
  end
end
