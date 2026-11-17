Threads
=======

``call set_num_threads(1_seams_int)`` sets the OpenMP width the next
analysis requests. ``num_threads()`` reports that width. After the
call above it returns 1. ``call set_num_threads(0_seams_int)`` restores
the default saved at startup.

The C image is ``seams_set_num_threads`` and ``seams_get_num_threads``.
Do not use one handle from two threads. The examples and the tests
set ``OMP_NUM_THREADS=1`` so the printed means are the one-thread
values.
