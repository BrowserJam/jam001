use crate::html::HTMLElement;
use anyhow::Context;
use pest::{iterators::Pair, Parser};
use pest_derive::Parser;

#[derive(Parser)]
#[grammar = "html.pest"]
pub struct HTMLParser;

pub fn parse(html: &str) -> anyhow::Result<Vec<HTMLElement>> {
    let pairs = HTMLParser::parse(Rule::html, html).context("Failed to parse HTML")?;
    let pairs = pairs
        .into_iter()
        .next()
        .context("rule::html doesn't have inner pairs")?
        .into_inner();
    let mut elements = Vec::new();

    for pair in pairs {
        match pair.as_rule() {
            Rule::element => {
                elements.push(parse_element(pair).context("Failed to parse element")?);
            }
            Rule::doctype => {}
            e => anyhow::bail!("Unexpected rule: {:?}", e),
        }
    }

    Ok(elements)
}

pub fn parse_element(pair: Pair<Rule>) -> anyhow::Result<HTMLElement> {
    let element = pair
        .into_inner()
        .next()
        .context("rule::element doesn't have inner element")?;
    match element.as_rule() {
        Rule::openCloseTag => parse_open_close_tag(element),
        Rule::selfClosingTag => parse_self_closing_tag(element),
        Rule::text => {
            let text = element.as_str().to_string();
            Ok(HTMLElement::text_node(text))
        }
        e => anyhow::bail!("Unexpected rule: {:?}", e),
    }
}

struct OpeningTag {
    tag: String,
    attributes: Vec<(String, String)>,
}

pub fn parse_opening_tag(pair: Pair<Rule>) -> anyhow::Result<OpeningTag> {
    let mut pair = pair.into_inner();
    let tag = pair.next().unwrap().as_str().to_string();
    let mut attributes = Vec::new();

    if let Rule::attributes = pair.peek().unwrap().as_rule() {
        let attributes_pairs = pair.next().unwrap();
        for attribute_pair in attributes_pairs.into_inner() {
            let mut attribute_pair = attribute_pair.into_inner();
            let attribute_name = attribute_pair.next().unwrap().as_str();
            let attribute_value = attribute_pair.next().unwrap().as_str();
            attributes.push((attribute_name.to_string(), attribute_value.to_string()));
        }
    }

    Ok(OpeningTag { tag, attributes })
}

pub fn parse_closing_tag(pair: Pair<Rule>) -> anyhow::Result<String> {
    let tag = pair.into_inner().next().unwrap().as_str().to_string();
    Ok(tag)
}

pub fn parse_content(pair: Pair<Rule>) -> anyhow::Result<Vec<HTMLElement>> {
    anyhow::ensure!(pair.as_rule() == Rule::content, "rule is not content");
    let pairs = pair.into_inner();
    let mut elements = Vec::new();

    for element in pairs {
        match element.as_rule() {
            Rule::element => {
                elements.push(parse_element(element).context("Failed to parse element")?);
            }
            Rule::text => {
                let text = element.as_str().to_string();
                elements.push(HTMLElement::text_node(text));
            }
            e => anyhow::bail!("Unexpected rule: {:?}", e),
        }
    }

    Ok(elements)
}

/// Parse <tag attributes>content</tag>
pub fn parse_open_close_tag(pair: Pair<Rule>) -> anyhow::Result<HTMLElement> {
    let mut pair = pair.into_inner();
    let opening_tag = parse_opening_tag(pair.next().unwrap())?;
    let content = parse_content(pair.next().unwrap())?;
    // let closing_tag = parse_closing_tag(pair.next().unwrap())?;

    // anyhow::ensure!(
    //     opening_tag.tag == closing_tag,
    //     "open tag and close tag doesn't match"
    // );

    Ok(HTMLElement::element(
        opening_tag.tag,
        opening_tag.attributes,
        content,
    ))
}

pub fn parse_self_closing_tag(pair: Pair<Rule>) -> anyhow::Result<HTMLElement> {
    let mut pair = pair.into_inner();

    if let Rule::br = pair.peek().unwrap().as_rule() {
        return Ok(HTMLElement::element("br".to_string(), vec![], vec![]));
    }

    if let Rule::meta = pair.peek().unwrap().as_rule() {
        return Ok(HTMLElement::element("meta".to_string(), vec![], vec![]));
    }

    let tag = pair.next().unwrap().as_str().to_string();
    let mut attributes = Vec::new();

    if let Rule::attributes = pair.peek().unwrap().as_rule() {
        let attributes_pairs = pair.next().unwrap();
        for attribute_pair in attributes_pairs.into_inner() {
            let mut attribute_pair = attribute_pair.into_inner();
            let attribute_name = attribute_pair.next().unwrap().as_str();
            let attribute_value = attribute_pair.next().unwrap().as_str();
            attributes.push((attribute_name.to_string(), attribute_value.to_string()));
        }
    }
    Ok(HTMLElement::element(tag, attributes, vec![]))
}
