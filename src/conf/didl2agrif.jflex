package gr.agroknow.metadata.transformer.didl2agrif;

import gr.agroknow.metadata.agrif.Agrif;
import gr.agroknow.metadata.agrif.Citation;
import gr.agroknow.metadata.agrif.ControlledBlock;
import gr.agroknow.metadata.agrif.Creator;
import gr.agroknow.metadata.agrif.Expression;
import gr.agroknow.metadata.agrif.Item;
import gr.agroknow.metadata.agrif.LanguageBlock;
import gr.agroknow.metadata.agrif.Manifestation;
import gr.agroknow.metadata.agrif.Relation;
import gr.agroknow.metadata.agrif.Rights;
import gr.agroknow.metadata.agrif.Publisher;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.List;
import java.util.ArrayList;

import net.zettadata.generator.tools.Toolbox;
import net.zettadata.generator.tools.ToolboxException;

%%
%class DIDL2AGRIF
%standalone
%unicode

%{
	// AGRIF
	private List<Agrif> agrifs ;
	private Agrif agrif ;
	private Citation citation ;
	private ControlledBlock cblock ;
	private Creator creator ;
	private Expression expression ;
	private Item item ;
	private LanguageBlock lblock ;
	private Manifestation manifestation ;
	private Relation relation ;
	private Rights rights ;
	private Publisher publisher ;
	
	// TMP
	private StringBuilder tmp ;
	private String language ;
	private String date = null ;
	private List<Publisher> publishers = new ArrayList<Publisher>() ;
	
	// EXERNAL
	private String potentialLanguages ;
	private String mtdLanguage ;
	private String providerId ;
	private String manifestationType = "landingPage" ;
	
	public void setPotentialLanguages( String potentialLanguages )
	{
		this.potentialLanguages = potentialLanguages ;
	}
	
	public void setMtdLanguage( String mtdLanguage )
	{
		this.mtdLanguage = mtdLanguage ;
	}
	
	public void setManifestationType( String manifestationType )
	{
		this.manifestationType = manifestationType ;
	}
	
	public void setProviderId( String providerId )
	{
		this.providerId = providerId ;
	}
	
	public List<Agrif> getAgrifs()
	{
		return agrifs ;
	}
	
	private void init()
	{
		agrif = new Agrif() ;
		agrif.setSet( providerId ) ;
		citation  = new Citation() ;
		cblock = new ControlledBlock() ;
		expression = new Expression() ;
		lblock = new LanguageBlock() ;
		relation = new Relation() ;
		rights = new Rights() ;
	}
	
	private String getLanguageFor( String text )
	{
		String result = null ;
		if ( mtdLanguage != null )
		{
			result = mtdLanguage ;
		}
		else
		{
			if ( potentialLanguages == null )
			{
				try
				{
					result = Toolbox.getInstance().detectLanguage( text ) ;
				}
				catch ( ToolboxException te){}
			}
			else
			{
				try
				{
					result = Toolbox.getInstance().detectLanguage( text, potentialLanguages ) ;
				}
				catch ( ToolboxException te){}
			}
		}
		return result ;
	}
	
	private String utcNow() 
	{
		Calendar cal = Calendar.getInstance();
		SimpleDateFormat sdf = new SimpleDateFormat( "yyyy-MM-dd" );
		return sdf.format(cal.getTime());
	}
	
	private String extract( String element )
	{	
		return element.substring(element.indexOf(">") + 1 , element.indexOf("</") );
	}
	
%}

%state AGRIF
%state DESCRIPTION
%state CITATION
%state TITLE

%%

<YYINITIAL>
{	
	
	"<oai_dc:dc"
	{
		agrifs = new ArrayList<Agrif>() ;
		init() ;
		yybegin( AGRIF ) ;
	}
}

<AGRIF>
{
	"</oai_dc:dc>"
	{
		for ( Publisher p: publishers )
		{
			expression.setPublisher( p ) ;
		}
		agrif.setExpression( expression ) ;
		agrif.setLanguageBlocks( lblock ) ;
		agrif.setControlled( cblock ) ;
		agrifs.add( agrif ) ;
		yybegin( YYINITIAL ) ;
	}
	
	
	"<dc:contributor>".+"</dc:contributor>"
	{
		// just ignore at the moment
	}
	
	"<dc:publisher>".+"</dc:publisher>"
	{
		publisher = new Publisher() ;
		publisher.setName( extract( yytext() ) ) ;
		publishers.add( publisher ) ;
	}
	
	"<dc:coverage>".+"</dc:coverage>"
	{
		cblock.setSpatialCoverage( "unknown", extract( yytext() ) ) ;
	}
	
	"<dc:source>".+"</dc:source>"
	{
		citation.setTitle( extract( yytext() ) ) ;
		expression.setCitation( citation ) ;
	}

	"<dc:date>".+"</dc:date>"
	{
		date = extract( yytext() ) ;
		if ( publishers.isEmpty() )
		{
			publisher = new Publisher() ;
			publisher.setDate( date ) ;
			expression.setPublisher( publisher ) ;
		}
		else
		{
			List<Publisher> ps = new ArrayList<Publisher>() ;
			for ( Publisher p: publishers )
			{
				p.setDate( date ) ;
				ps.add( p ) ;
			}
			publishers = ps ;
		}
	}

	"<dc:type>".+"</dc:type>"
	{
		String type = extract( yytext() ) ;
		if ( "PeerReviewed".equals( type ) )
		{
			cblock.setReviewStatus( "dcterms", type ) ;	
		}
		else
		{
			cblock.setType( "dcterms", type ) ;
		}
	}
	
	"<dc:rights>http://".+"</dc:rights>"
	{
		rights.setIdentifier( extract( yytext() ) ) ;
		agrif.setRights( rights ) ;
	}
	
	"<dc:rights>".+"</dc:rights>"
	{
		String tmptext = extract( yytext() ) ;
		language = getLanguageFor( tmptext ) ;
		rights.setRightsStatement( language, tmptext ) ;
		agrif.setRights( rights ) ;  
	}
	
	"<dc:language>".+"</dc:language>"
	{
		language = extract( yytext() ) ;
		if ( language.length() == 3 )
		{
			try
			{
				language = Toolbox.getInstance().toISO6391( language ) ;
			}
			catch( ToolboxException te ) {}
		} 
		expression.setLanguage( language ) ;
	}
	
	"<dc:format>".+"</dc:format>"
	{
		// manifestation.setFormat( extract( yytext() ) ) ;
	}
	
	"<dc:relation>http://".+".pdf</dc:relation>"
	{
		// ignore for now
	}
	
	
	"<dc:relation>http://".+"</dc:relation>"
	{
		item = new Item() ;
		item.setDigitalItem( extract( yytext() ) ) ;
		manifestation = new Manifestation() ;
		manifestation.setItem( item ) ;
		manifestation.setManifestationType( "landingPage" ) ;
		expression.setManifestation( manifestation ) ;
	}
	
	"<dc:identifier>".+".pdf</dc:identifier>"
	{
		manifestation = new Manifestation() ;
		item = new Item() ;
		item.setDigitalItem( extract( yytext() ) ) ;
		manifestation.setManifestationType( "fullText" ) ;
		manifestation.setFormat( "application/pdf" ) ;
		manifestation.setItem( item ) ;
		expression.setManifestation( manifestation ) ;
	}
	
	"<dc:identifier>"
	{
		citation = new Citation() ;
		tmp = new StringBuilder() ;
		yybegin( CITATION ) ;
	}
	
	"<dc:title>"
	{
		yybegin( TITLE ) ;
		tmp = new StringBuilder() ;
	}
	
	"<dc:creator>".+"</dc:creator>"
	{
		creator = new Creator() ;
		creator.setName( extract( yytext() ) ) ;
		creator.setType( "person" ) ;
		agrif.setCreator( creator ) ;
	}
	
	"<dc:subject>".+"</dc:subject>"
	{
		String tmptext = extract( yytext() ) ;
		language = getLanguageFor( tmptext ) ;
		lblock.setKeyword( language, tmptext ) ;
	}
	
	"<dc:description>"
	{
		tmp = new StringBuilder() ;
		yybegin( DESCRIPTION ) ;
	}
	
}

<TITLE>
{
	"</dc:title>"
	{
		String tmptext = tmp.toString() ;
		language = getLanguageFor( tmptext ) ;
		yybegin( AGRIF ) ;
		if ( lblock.hasTitle( language ) )
		{
			lblock.setAlternativeTitle( language, tmptext ) ;
		}
		else
		{
			lblock.setTitle( language, tmptext ) ;
		}
	}
	
	"&#xD;"
	{}
	
	"’"
	{
		tmp.append( "'" ) ;
	}

	
	\r|\n
	{
		tmp.append( " " ) ;
	}
	
	.
	{
		tmp.append( yytext() ) ;
 	}

}

<CITATION>
{
	"</dc:identifier>"
	{
		citation.setTitle( tmp.toString() ) ;
		expression.setCitation( citation ) ;
		yybegin( AGRIF ) ;
	}

	.|\n
	{
		tmp.append( yytext() ) ;
	}


}

<DESCRIPTION>
{
	"</dc:description>"
	{
		yybegin( AGRIF ) ;
		String tmptext = tmp.toString() ;
		language = getLanguageFor( tmptext ) ;
		lblock.setAbstract( language, tmptext ) ;
	}
	
	"’"
	{
		tmp.append( "'" ) ;
	}
	
	"&#xD;"
	{}
	
	\r|\n
	{
		tmp.append( " " ) ;
	}
	
	.
	{
		tmp.append( yytext() ) ;
 	}
}

/* error fallback */
.|\n 
{
	//throw new Error("Illegal character <"+ yytext()+">") ;
}