import SoPlex
using Test

macro isdefined(var)
    quote
        try
            local _ = $(esc(var))
            true
        catch err
            isa(err, UndefVarError) ? false : rethrow(err)
        end
    end
end

function test_real()
   # create LP via columns 

   soplex = SoPlex_create()
   infty = 10e+20
   colentries1 = [-1.0]
   colentries2 = [1.0]
   lhs = [-10.0]
   primal = [0.0,0.0]

   # minimize 
   SoPlex_setIntParam(soplex, 0, -1)

   # add columns 
   SoPlex_addColReal(soplex, colentries1, 1, 1, 1.0, 0.0, infty)
   SoPlex_addColReal(soplex, colentries2, 1, 1, 1.0, -infty, infty)
   assert(SoPlex_numRows(soplex) == 1)
   assert(SoPlex_numCols(soplex) == 2)

   # set lhs of constra
   SoPlex_changeLhsReal(soplex, lhs, 1)

   # optimize and get solution and objective value 
   result = SoPlex_optimize(soplex)
   assert(result == 1)
   SoPlex_getPrimalReal(soplex, primal, 2)
   assert(primal[0] == 0.0 && primal[1] == -10.0)
   assert(SoPlex_objValueReal(soplex) == -10.0)

	SoPlex_free(soplex)

   # create LP via rows 

   soplex2 = SoPlex_create()
   rowentries1 = [-1.0, 1.0]
   lb = [0.0, -infty]
   ub = [infty, infty]
   obj = [1.0, 1.0]

   # minimize 
   SoPlex_setIntParam(soplex2, 0, -1)

   # add row 
   SoPlex_addRowReal(soplex2, rowentries1, 2, 2, -10.0, infty)

   # add variable bounds 
   SoPlex_changeBoundsReal(soplex2, lb, ub, 2)
   assert(SoPlex_numRows(soplex2) == 1)
   assert(SoPlex_numCols(soplex2) == 2)

   # add objective 
   SoPlex_changeObjReal(soplex2, obj, 2)

   # optimize and get solution and objective value 
   result = SoPlex_optimize(soplex2)
   assert(result == 1)
   SoPlex_getPrimalReal(soplex2, primal, 2)
   assert(primal[0] == 0.0 && primal[1] == -10.0)
   assert(SoPlex_objValueReal(soplex2) == -10.0)

	SoPlex_free(soplex2)
end

if @isdefined(SOPLEX_WITH_GMP)
   function test_rational()
      # create LP via rows 

      soplex = SoPlex_create()
      infty = 1000000
      rownums = [-1, 1]
      rowdenoms = [1, 1]
      objnums = [1, 1]
      objdenoms = [1, 1]
      primal = [0.0,0.0]

      # use rational solver 
      SoPlex_setRational(soplex)

      # minimize 
      SoPlex_setIntParam(soplex, 0, -1)

      # add row and set objective function 
      SoPlex_addRowRational(soplex, rownums, rowdenoms, 2, 2, 1, 5, infty, 1)
      SoPlex_changeObjRational(soplex, objnums, objdenoms, 2)

      # optimize and check rational solution and objective value 
      result = SoPlex_optimize(soplex)
      assert(result == 1)
      assert(strcmp(SoPlex_getPrimalRationalString(soplex, 2), "0 1/5 ") == 0)
      assert(strcmp(SoPlex_objValueRationalString(soplex), "1/5") == 0)

      SoPlex_free(soplex)

      # create LP via columns 
      soplex2 = SoPlex_create()
      colnums1 = [-1]
      coldenoms1 = [1]
      colnums2 = [1]
      coldenoms2 = [1]
      lhsnums = [-1]
      lhsdenoms = [5]

      # use rational solver 
      SoPlex_setRational(soplex2)

      # minimize 
      SoPlex_setIntParam(soplex2, 0, -1)

      # add cols 
      SoPlex_addColRational(soplex2, colnums1, coldenoms1, 1, 1, 1, 5, 0, 1, infty, 1)
      SoPlex_addColRational(soplex2, colnums2, coldenoms2, 1, 1, 1, 5, -infty, 1, infty, 1)

      # add bounds to constra
      SoPlex_changeLhsRational(soplex2, lhsnums, lhsdenoms, 1)

      # optimize and check rational solution and objective value 
      result = SoPlex_optimize(soplex2)
      assert(result == 1)
      assert(strcmp(SoPlex_getPrimalRationalString(soplex2, 2), "0 -1/5 ") == 0)
      assert(strcmp(SoPlex_objValueRationalString(soplex2), "-1/25") == 0)

      SoPlex_free(soplex2)
   end
end

function main()
   printf("testing real... \n")
   test_real()

   if @isdefined(SOPLEX_WITH_GMP)
      printf("\n")
      printf("testing rational... \n")
      test_rational()
   end
end
