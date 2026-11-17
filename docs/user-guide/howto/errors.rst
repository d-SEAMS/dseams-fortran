Errors
======

Pass ``stat`` and ``errmsg``, or neither. With neither, a failed call
``error stop``\ s with the library message. With ``stat``, the
``seams.h`` code is stored and the program continues. ``errmsg``
receives the detail from ``seams_handle_error``. ``status_text`` is
the short name of that code.

A negative edge is ``SEAMS_ERR_BOX`` (3):

.. code-block:: fortran

   program errors
     use seams
     implicit none
     type(seams_frame) :: frame
     real(seams_real) :: xyz(3, 1)
     integer(seams_int) :: stat
     character(len=:), allocatable :: err
     xyz = 0
     frame = new_frame()
     call frame%set_ortho(xyz, -1.0_seams_real, 1.0_seams_real, 1.0_seams_real, &
       stat=stat, errmsg=err)
     print "(a,i0)", "stat ", stat
     print "(a,a)", "status ", status_text(stat)
     print "(a,a)", "error ", err
     call frame%close()
   end program errors

.. code-block:: text

   stat 3
   status box is not a positive cell
   error box edge lengths must be positive

The codes are

.. list-table::
   :header-rows: 1

   * - name
     - value
     - meaning
   * - ``SEAMS_OK``
     - 0
     - the call succeeded
   * - ``SEAMS_ERR_NULL``
     - 1
     - a required pointer is null
   * - ``SEAMS_ERR_RANGE``
     - 2
     - a number is outside the accepted range
   * - ``SEAMS_ERR_BOX``
     - 3
     - the cell is missing or has no volume
   * - ``SEAMS_ERR_ARG``
     - 4
     - a caller argument is the wrong shape
   * - ``SEAMS_ERR_STATE``
     - 5
     - the handle has no frame yet
   * - ``SEAMS_ERR_NOMEM``
     - 6
     - an allocation failed
   * - ``SEAMS_ERR_INTERNAL``
     - 7
     - the library hit an internal failure
