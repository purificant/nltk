NLTK testing
============

1. Obtain nltk source code;
2. install virtualenv and tox::

       pip install virtualenv
       pip install tox

3. make sure currently supported python versions
   and pypy executables are in system PATH. It is OK not to have all the
   executables, tests will be executed for available interpreters.

4. Make sure all NLTK data is downloaded (see ``nltk.download()``);

5. run 'tox' command from the root nltk folder. It will install dependencies
   and run ``pytest`` for all available interpreters.
   You may also pass any pytest options after ``--`` (for example, ``-v``
   for verbose).

It may take a long time at first run, but the subsequent runs will
be much faster.

Please consult https://tox.wiki for more info about the tox tool.

Examples
--------

Run tests for python 3.14 in verbose mode; executing only tests
that failed in the last test run::

    tox -e py314 -- -v --last-failed

Run tree doctests for all available interpreters::

    tox -- tree.doctest

Run a selected unit test file for Python 3.14. Paths are relative to
``nltk/test``::

    tox -e py314 -- -v unit/test_seekable_unicode_stream_reader.py

By default, numpy, scipy and scikit-learn are installed in tox virtualenvs.
This is slow, requires working build toolchain and is not always feasible.
In order to skip numpy & friends, use ``..-nodeps`` environments::

    tox -e py314-nodeps,py314,pypy

It is also possible to run tests without tox. This way NLTK would be tested
only under single interpreter, but it may be easier to have numpy and other
libraries installed this way. In order to run tests without tox, make sure
to ``pip install -e . -r requirements-ci.txt`` and run ``pytest``::

    pytest nltk/test/


Writing tests
-------------

Unlike most open-source projects, NLTK test suite is doctest-based.
This format is very expressive, and doctests are usually read
as documentation. We don't want to rewrite them to unittests;
if you're contributing code to NLTK please prefer doctests
for testing.

Doctests are located at ``nltk/test/*.doctest`` text files and
in docstrings for modules, classes, methods and functions.

That said, doctests have their limitations and sometimes it is better to use
unittests. Test should be written as unittest if it is a regression test that
is not necessary for documentational purposes.

Unittests currently reside in ``nltk/test/unit/test_*.py`` files; pytest
is used for test running.

If a test should be written as unittest but also has a documentational value
then it should be duplicated as doctest, but with a "# doctest: +SKIP" option.

There are some gotchas with NLTK doctests (and with doctests in general):

* Don't write ``+ELLIPSIS``, ``+NORMALIZE_WHITESPACE``,
  ``+IGNORE_EXCEPTION_DETAIL`` flags (they are already ON by default in NLTK).

* To skip a ``nltk/test/foo.doctest`` file when a condition is not met, write
  a helper in ``nltk/test/foo_fixt.py``::

      # <a comment describing why the doctest should be skipped>

      def setup_module():
          import pytest

          if some_condition:
              pytest.skip("foo.doctest is skipped because <...>")

  and call it at the top of the doctest::

      >>> from nltk.test.foo_fixt import setup_module
      >>> setup_module()

  pytest does not load ``_fixt.py`` files by itself, so the doctest has to
  make this call. The skip covers the whole file. For a missing package,
  ``pytest.importorskip("numpy")`` checks and skips in one call.

* To skip a doctest in a module, class or function docstring, run the check
  at the top of that docstring. The skip covers only that docstring. For an
  external program, ``nltk/test/setup_fixt.py`` has ``check_binary``::

      >>> from nltk.test.setup_fixt import check_binary
      >>> check_binary('dot')

  pytest does not run a module-level ``setup_module`` for docstring doctests,
  so every docstring that needs the skip has to make the call.

* Do not expect the exact float output; this may fail on some machines::

      >>> some_float_constant
      0.867

  Use ellipsis in this case to make the test robust (or compare the values)::

      >>> some_float_constant
      0.867...

      >>> abs(some_float_constant - 0.867) < 1e-6
      True

* Do not rely on dictionary or set item order. Incorrect::

      >>> some_dict
      {"x": 10, "y": 20}

  The proper way is to sort the items and print them::

      >>> for key, value in sorted(some_dict.items()):
      ...     print(key, value)
      x 10
      y 20

If the code requires some external dependencies, then

* tests for this code should be skipped if the dependencies are not available:
  skip doctests as described above and use
  ``@pytest.mark.skipif / @pytest.mark.skip`` decorators or ``pytest.skip``
  exception for unittests;
* if the dependency is a Python package, it should be added to
  ``requirements-ci.txt`` and ``tox.ini`` (but not to ..-nodeps environments).
