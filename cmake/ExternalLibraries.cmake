## Copyright (C) 2020 Alex Mayfield
## Copyright (C) 2020 Max Waine
##
## This software is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This software is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 51 Franklin St, Fifth Floor,
## Boston, MA  02110-1301  USA
##

set(DOWNLOAD_LIB, FALSE)
function(check_lib_needs_downloading LIBRARY INCLUDE_DIR LIBRARY_DIR)
   set(${DOWNLOAD_LIB} FALSE PARENT_SCOPE)

   if(NOT DEFINED ${LIBRARY} OR NOT DEFINED ${INCLUDE_DIR})
      set(DOWNLOAD_LIB TRUE PARENT_SCOPE)
      return()
   endif()

   if(DEFINED ${LIBRARY} AND NOT EXISTS ${${LIBRARY}})
      set(DOWNLOAD_LIB TRUE PARENT_SCOPE)
      return()
   endif()

   if(DEFINED ${INCLUDE_DIR} AND NOT EXISTS ${${INCLUDE_DIR}})
      set(DOWNLOAD_LIB TRUE PARENT_SCOPE)
      return()
   endif()
  
   if(WIN32)
      if(MSVC)
         if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/${LIBRARY_DIR}")
            set(DOWNLOAD_LIB TRUE PARENT_SCOPE)
            return()
         endif()
      else()
         if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/${LIBRARY_DIR}/x86_64-w64-mingw32")
               set(DOWNLOAD_LIB TRUE PARENT_SCOPE)
               return()
            endif()
         else()
            if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/${LIBRARY_DIR}/i686-w64-mingw32")
               set(DOWNLOAD_LIB TRUE PARENT_SCOPE)
               return()
            endif()
         endif()
      endif()
   endif()
endfunction()

find_package(OpenGL)

### SDL2 ###

set(SDL2_VERSION "SDL2-2.0.14" CACHE STRING "" FORCE)
check_lib_needs_downloading(SDL2_LIBRARY SDL2_INCLUDE_DIR ${SDL2_VERSION})
if(WIN32 AND DOWNLOAD_LIB)
   if(MSVC)
      file(DOWNLOAD
         "https://www.libsdl.org/release/SDL2-devel-2.0.14-VC.zip"
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2-VC.zip"
         EXPECTED_HASH SHA256=232071cf7d40546cde9daeddd0ec30e8a13254c3431be1f60e1cdab35a968824)
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2-VC.zip"
         WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")

      set(SDL2_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_VERSION}")
      set(SDL2_INCLUDE_DIR "${SDL2_DIR}/include" CACHE PATH "" FORCE)
      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
         set(SDL2_LIBRARY "${SDL2_DIR}/lib/x64/SDL2.lib" CACHE FILEPATH "" FORCE)
         set(SDL2MAIN_LIBRARY "${SDL2_DIR}/lib/x64/SDL2main.lib" CACHE FILEPATH "" FORCE)
      else()
         set(SDL2_LIBRARY "${SDL2_DIR}/lib/x86/SDL2.lib" CACHE FILEPATH "")
         set(SDL2MAIN_LIBRARY "${SDL2_DIR}/lib/x86/SDL2main.lib" CACHE FILEPATH "" FORCE)
      endif()
   else()
      file(DOWNLOAD
         "https://www.libsdl.org/release/SDL2-devel-2.0.14-mingw.tar.gz"
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2-mingw.tar.gz"
         EXPECTED_HASH SHA256=405eaff3eb18f2e08fe669ef9e63bc9a8710b7d343756f238619761e9b60407d)
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2-mingw.tar.gz"
         WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")

      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
         set(SDL2_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_VERSION}/x86_64-w64-mingw32")
      else()
         set(SDL2_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_VERSION}/i686-w64-mingw32")
      endif()
      set(SDL2_INCLUDE_DIR "${SDL2_DIR}/include/SDL2" CACHE PATH "" FORCE)
      set(SDL2_LIBRARY "${SDL2_DIR}/lib/libSDL2.dll.a" CACHE FILEPATH "" FORCE)
      set(SDL2MAIN_LIBRARY "${SDL2_DIR}/lib/libSDL2main.a" CACHE FILEPATH "" FORCE)
   endif()
endif()

if(APPLE)
   execute_process(
      COMMAND ${CMAKE_SOURCE_DIR}/macosx/download_sdl.sh
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
   )
   set(SDL2_LIBRARY "-framework SDL2" CACHE FILEPATH "")
   set(SDL2_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/SDL2.Framework/Headers CACHE FILEPATH "")

   set(SDL2_MAIN_LIBRARY "" CACHE FILEPATH "")

   set(SDL2_MIXER_LIBRARY "-framework SDL2_mixer" CACHE FILEPATH "")
   set(SDL2_MIXER_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/SDL2_mixer.Framework/Headers CACHE FILEPATH "")

   set(SDL2_NET_LIBRARY "-framework SDL2_net" CACHE FILEPATH "")
   set(SDL2_NET_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/SDL2_net.Framework/Headers CACHE FILEPATH "")

   # Needed for access
   if(NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/SDL2)
      file(
         CREATE_LINK ${CMAKE_CURRENT_BINARY_DIR}/SDL2.Framework/Headers
               ${CMAKE_CURRENT_BINARY_DIR}/SDL2 SYMBOLIC
      )
   endif()
endif()

find_package(SDL2)

if(SDL2_FOUND)
   # SDL2 target.
   add_library(SDL2::SDL2 UNKNOWN IMPORTED GLOBAL)
   set_target_properties(SDL2::SDL2 PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${SDL2_INCLUDE_DIR}"
      IMPORTED_LOCATION "${SDL2_LIBRARY}")

   if(SDL2MAIN_LIBRARY)
      # SDL2main target.
      if(MINGW)
         # Gross hack to get mingw32 first in the linker order.
         add_library(SDL2::_SDL2main_detail UNKNOWN IMPORTED GLOBAL)
         set_target_properties(SDL2::_SDL2main_detail PROPERTIES
            IMPORTED_LOCATION "${SDL2MAIN_LIBRARY}")

         # Ensure that SDL2main comes before SDL2 in the linker order.  CMake
         # isn't smart enough to keep proper ordering for indirect dependencies
         # so we have to spell it out here.
         target_link_libraries(SDL2::_SDL2main_detail INTERFACE SDL2::SDL2)

         add_library(SDL2::SDL2main INTERFACE IMPORTED GLOBAL)
         set_target_properties(SDL2::SDL2main PROPERTIES
            IMPORTED_LIBNAME mingw32)
         target_link_libraries(SDL2::SDL2main INTERFACE SDL2::_SDL2main_detail)
      else()
         add_library(SDL2::SDL2main UNKNOWN IMPORTED GLOBAL)
         set_target_properties(SDL2::SDL2main PROPERTIES
            IMPORTED_LOCATION "${SDL2MAIN_LIBRARY}")
      endif()
   endif()
endif()

### SDL2_mixer ###

set(SDL2_MIXER_VERSION "SDL2_mixer-2.6.2" CACHE STRING "" FORCE)
check_lib_needs_downloading(SDL2_MIXER_LIBRARY SDL2_MIXER_INCLUDE_DIR ${SDL2_MIXER_VERSION})
if(WIN32 AND DOWNLOAD_LIB)
   if(MSVC)
      file(DOWNLOAD
         "https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-devel-2.6.2-VC.zip"
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_mixer-VC.zip"
         EXPECTED_HASH SHA256=7F050663CCC7911BB9C57B11E32CA79578B712490186B8645DDBBE4E7D2FE1C9)
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_mixer-VC.zip"
         WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")

      set(SDL2_MIXER_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_MIXER_VERSION}")
      set(SDL2_MIXER_INCLUDE_DIR "${SDL2_MIXER_DIR}/include" CACHE PATH "" FORCE)
      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
         set(SDL2_MIXER_LIBRARY "${SDL2_MIXER_DIR}/lib/x64/SDL2_mixer.lib" CACHE FILEPATH "" FORCE)
      else()
         set(SDL2_MIXER_LIBRARY "${SDL2_MIXER_DIR}/lib/x86/SDL2_mixer.lib" CACHE FILEPATH "" FORCE)
      endif()
   else()
      file(DOWNLOAD
         "https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-devel-2.6.2-mingw.tar.gz"
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_mixer-mingw.tar.gz"
         EXPECTED_HASH SHA256=6C414D05A3B867E0D59E0F9B28EA7E5E64527E612CCF961735DC2478391315B3)
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_mixer-mingw.tar.gz"
         WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")

      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
         set(SDL2_MIXER_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_MIXER_VERSION}/x86_64-w64-mingw32")
      else()
         set(SDL2_MIXER_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_MIXER_VERSION}/i686-w64-mingw32")
      endif()
      set(SDL2_MIXER_INCLUDE_DIR "${SDL2_MIXER_DIR}/include/SDL2" CACHE PATH "" FORCE)
      set(SDL2_MIXER_LIBRARY "${SDL2_MIXER_DIR}/lib/libSDL2_mixer.dll.a" CACHE FILEPATH "" FORCE)
   endif()
endif()

find_package(SDL2_mixer)

if(SDL2_MIXER_FOUND)
   # SDL2_mixer target.
   add_library(SDL2::mixer UNKNOWN IMPORTED GLOBAL)
   set_target_properties(SDL2::mixer PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${SDL2_MIXER_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES SDL2::SDL2
      IMPORTED_LOCATION "${SDL2_MIXER_LIBRARY}")
endif()

### SDL2_net ###

set(SDL2_NET_VERSION "SDL2_net-2.0.1" CACHE STRING "" FORCE)
check_lib_needs_downloading(SDL2_NET_LIBRARY SDL2_NET_INCLUDE_DIR ${SDL2_NET_VERSION})
if(WIN32 AND DOWNLOAD_LIB)
   if(MSVC)
      file(DOWNLOAD
         "https://www.libsdl.org/projects/SDL_net/release/SDL2_net-devel-2.0.1-VC.zip"
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_net-VC.zip"
         EXPECTED_HASH SHA256=c1e423f2068adc6ff1070fa3d6a7886700200538b78fd5adc36903a5311a243e)
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_net-VC.zip"
         WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")

      set(SDL2_NET_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_NET_VERSION}")
      set(SDL2_NET_INCLUDE_DIR "${SDL2_NET_DIR}/include" CACHE PATH "" FORCE)
      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
         set(SDL2_NET_LIBRARY "${SDL2_NET_DIR}/lib/x64/SDL2_net.lib" CACHE FILEPATH "" FORCE)
      else()
         set(SDL2_NET_LIBRARY "${SDL2_NET_DIR}/lib/x86/SDL2_net.lib" CACHE FILEPATH "" FORCE)
      endif()
   else()
      file(DOWNLOAD
         "https://www.libsdl.org/projects/SDL_net/release/SDL2_net-devel-2.0.1-mingw.tar.gz"
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_net-mingw.tar.gz"
         EXPECTED_HASH SHA256=fe0652ab1bdbeae277d7550f2ed686a37a5752f7a624f54f19cf1bd6ba5cb9ff)
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf
         "${CMAKE_CURRENT_BINARY_DIR}/SDL2_net-mingw.tar.gz"
         WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")

      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
         set(SDL2_NET_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_NET_VERSION}/x86_64-w64-mingw32")
      else()
         set(SDL2_NET_DIR "${CMAKE_CURRENT_BINARY_DIR}/${SDL2_NET_VERSION}/i686-w64-mingw32")
      endif()
      set(SDL2_NET_INCLUDE_DIR "${SDL2_NET_DIR}/include/SDL2" CACHE PATH "" FORCE)
      set(SDL2_NET_LIBRARY "${SDL2_NET_DIR}/lib/libSDL2_net.dll.a" CACHE FILEPATH "" FORCE)
   endif()
endif()

find_package(SDL2_net)

if(SDL2_NET_FOUND)
   # SDL2_net target.
   add_library(SDL2::net UNKNOWN IMPORTED GLOBAL)
   set_target_properties(SDL2::net PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${SDL2_NET_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES SDL2::SDL2
      IMPORTED_LOCATION "${SDL2_NET_LIBRARY}")
endif()

## EOF

