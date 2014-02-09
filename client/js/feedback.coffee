# Oye - simple WebRTC hub
# Copyright (C) 2014 lamikae
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# This is author's own vanity feature.
class oye.Feedback

  constructor: ->
    $("#feedback input[type=button]").on "click", (e) ->
      text = $("#feedback textarea")[0].value
      return if text == ""
      $.ajax
        type: 'POST',
        data: {text: text},
        dataType: 'text',

        beforeSend: (jqXHR, settings) ->

        success: (data, textStatus, jqXHR) ->
          $("#feedback textarea").hide()
          $("#feedback").text("Thank you")

        error: (jqXHR, textStatus, errorThrown) ->
          console.log textStatus, errorThrown

        complete: (jqXHR, textStatus) ->
          if jqXHR.status == 400 or jqXHR.status == 401
            # 200 : all ok
            # 400 : validation / handled backend error
            message = jqXHR.responseText
            console.log message

          else if jqXHR.status == 500
            error_message = "#{textStatus} #{jqXHR.status}"
            console.log error_message


