function   cssm( cell_array, filespec )
% writecell() function, but without the unwanted quotation marks in the
% written .txt file
    fid = fopen( filespec, 'wt' );
    for jj = 1 : length( cell_array )
        fprintf( fid, '%s\n', cell_array{jj} );
    end
    fclose( fid );
end